import asyncdispatch
import macros
import mimetypes
import strutils
import tables
import re
import streams, asyncfile, asyncnet
import httpcore
import times

macro getName*(x: typed, default: string = ""): string =
  if x.kind == nnkCall and len(x) > 0 and x[0].kind == nnkSym:
    newLit x[0].getImpl[0].strVal
  elif x.kind == nnkSym:
    newLit x.getImpl[0].strVal
  else:
    newLit default.strVal

proc getType*(mime: string): string =
  # TODO: Test this
  let m = newMimetypes() # TODO: Reuse instance?
  result = m.getMimetype(mime, default = "")
  if result != "":
    if not result.contains("charset"):
      if result.match(re("^text/", {reStudy, reIgnoreCase})):
        result.add "; charset=utf-8"

# echo "TYPE: ", getType("html")

proc parseContentType*(contentType: string): (string, Table[string, string]) {.gcsafe.} =
  # TODO: Test this
  let PARAM_REGEXP = re"""; *([!#$%&'*+.^_`|~0-9A-Za-z-]+) *= *("(?:[\x{000b}\x{0020}\x{0021}\x{0023}-\x{005b}\x{005d}-\x{007e}\x{0080}-\x{00ff}]|\\[\x{000b}\x{0020}-\x{00ff}])*"|[!#$%&'*+.^_`|~0-9A-Za-z-]+) *"""
  let QESC_REGEXP = re"""\\([\x{000b}\x{0020}-\x{00ff}])"""

  var index = contentType.find(";")
  let mime = (if index != -1: contentType[0..index] else: contentType).strip
  result[0] = mime
  if index != -1:
    while true:
      var matches: array[2, string]
      let length = contentType.matchLen(PARAM_REGEXP, matches, index)
      if length <= 0: break
      index.inc(length)
      let key = matches[0].toLower
      var value = matches[1]
      if value[0] == '"':
        value = value[1..<len(value)-1].replacef(QESC_REGEXP, "$1")
      result[1][key] = value

# echo parseContentType("text/html; charset=utf-8; asadsa=fdsfds; boundary=\"some\\ thing\"")


proc humanizeNumber*(n: int|float, delimiter: string = ",",
    separator: string = "."): string =
  # TODO: Test this
  var num = ($n).split(".")
  if len(num) > 1 and num[1] == "0":
    num.del(1)
  num[0] = num[0].replacef(re"""(\d)(?=(\d\d\d)+(?!\d))""", "$1" & delimiter)
  return num.join(separator)


const unitMap = {
  "b": 1,
  "kb": 1 shl 10,
  "mb": 1 shl 20,
  "gb": 1 shl 30,
  "tb": 1 shl 40,
  "pb": 1 shl 50
}.toTable

proc bytes*(value: int64|float64|int, thousandsSeparator: string = "",
    unitSeparator: string = "", decimalPlaces: int = 2,
    fixedDecimals: bool = false, unit: string = ""): string =
  # TODO: Test this
  let formatDecimalsRegExp = re"""(?:\.0*|(\.[^0]+)0+)$"""
  let formatThousandsRegExp = re"""\B(?=(\d{3})+(?!\d))"""

  let mag = abs(int(value))

  var newUnit = unit # unit is immutable, have to store in var

  if newUnit == "" or unitMap.hasKey(newUnit.toLower):
    if mag >= unitMap["pb"]:
      newUnit = "PB"
    elif mag >= unitMap["tb"]:
      newUnit = "TB"
    elif mag >= unitMap["gb"]:
      newUnit = "GB"
    elif mag >= unitMap["mb"]:
      newUnit = "MB"
    elif mag >= unitMap["kb"]:
      newUnit = "KB"
    else:
      newUnit = "B"

  let val = float(value) / float(unitMap[newUnit.toLower])
  var str = val.formatFloat(format = ffDecimal, precision = decimalPlaces)

  if not fixedDecimals:
    str = str.replacef(formatDecimalsRegExp, "$1")

  if thousandsSeparator != "":
    str = str.replace(formatThousandsRegExp, thousandsSeparator)

  return str & unitSeparator & newUnit

proc pipe*(stream: Stream, socket: AsyncSocket, bufferSize: int = 1024) {.async.} =
  let buffer = alloc(bufferSize)
  defer:
    dealloc(buffer)

  while not stream.atEnd:
    let readBytes = stream.readData(buffer, bufferSize)
    if readBytes == 0:
      break
    await socket.send(buffer, readBytes)
  stream.close()

proc pipe*(file: AsyncFile, socket: AsyncSocket, bufferSize: int = 1024) {.async.} =
  let buffer = alloc(bufferSize)
  defer:
    dealloc(buffer)

  while true:
    let readBytes = await file.readBuffer(buffer, bufferSize)
    if readBytes == 0:
      break
    await socket.send(buffer, readBytes)
  file.close()

proc parseLastModified*(header: string): DateTime|Time =
  return parse(header, "ddd, dd MMM yyyy HH:mm:ss 'GMT'", utc())
proc formatLastModified*(lastmod: DateTime|Time): string =
  return format(lastmod, "ddd, dd MMM yyyy HH:mm:ss 'GMT'")

proc parseTokenList(str: string): seq[string] =
  var endPos = 0
  var startPos = 0
  for i in 0..<len(str):
    case ord str[i]
      of 0x20:
        if startPos == endPos:
          startPos = i + 1
          endPos = startPos
      of 0x2C:
        result.add(str[startPos..endPos])
        startPos = i + 1
        endPos = startPos
      else:
        endPos = i + 1
  result.add(str[startPos..endPos])

proc fresh*(reqHeaders: HttpHeaders, resHeaders: HttpHeaders): bool =
  # TODO: Test this
  result = false
  let CACHE_CONTROL_NO_CACHE_REGEXP = re"""(?:^|,)\s*?no-cache\s*?(?:,|$)"""

  if not reqHeaders.hasKey("if-modified-since") and not reqHeaders.hasKey("if-none-match"):
    return

  let modifiedSince = reqHeaders["if-modified-since"]
  let noneMatch = reqHeaders["if-none-match"]

  let cacheControl = reqHeaders["cache-control"]
  if cacheControl != "" and cacheControl.match(CACHE_CONTROL_NO_CACHE_REGEXP):
    return

  if reqHeaders.hasKey("if-none-match") and noneMatch != "*":
    if resHeaders.hasKey("etag"):
      return
    let etag = resHeaders["etag"]
    var etagStale = true
    let matches = parseTokenList(noneMatch)
    for i, match in matches:
      if match == etag or match == "W/" & etag or match & "W/" == etag:
        etagStale = false
        break

    if etagStale:
      return

  if reqHeaders.hasKey("if-modified-since"):
    if not resHeaders.hasKey("last-modified"):
      return
    let lastModified = resHeaders["last-modified"]
    if parseLastModified(lastModified) <= parseLastModified(modifiedSince):
      return

  return true
