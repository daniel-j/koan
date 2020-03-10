from mimetypes import newMimetypes, getMimetype
import re
import strutils
import macros
import tables

macro getName*(x: typed, default:string = ""): string =
  if x.kind == nnkSym:
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
      var matches:array[2, string]
      let length = contentType.matchLen(PARAM_REGEXP, matches, index)
      if length <= 0: break
      index.inc(length)
      let key = matches[0].toLower
      var value = matches[1]
      if value[0] == '"':
        value = value[1..<len(value)-1].replacef(QESC_REGEXP, "$1")
      result[1][key] = value

# echo parseContentType("text/html; charset=utf-8; asadsa=fdsfds; boundary=\"some\\ thing\"")


