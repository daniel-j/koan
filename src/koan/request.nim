import uri
import parseutils
import strutils
import httpcore
import tables
from asynchttpserver as http import nil

import ./util

type
  Request* = ref object of RootObj
    req*: http.Request
    originalUrl*: string

proc headers*(this: Request): HttpHeaders = return this.req.headers

proc url*(this: Request): string =
  return $this.req.url

proc `url=`*(this: Request, url: string) =
  this.req.url = parseUri(url)

proc `method`*(this: Request): HttpMethod =
  return this.req.reqMethod

proc originalUrl*(this: Request): string =
  return this.originalUrl

proc length*(this: Request): int =
  result = -1
  if this.headers.hasKey("Content-Length"):
    discard parseInt(this.headers["Content-Length"], result)

proc type*(this: Request): string =
  return this.req.headers.getOrDefault("Content-Type").split(";", 1)[0]

proc charset*(this: Request): string =
  if not this.req.headers.hasKey("Content-Type"):
    return
  let contentType = parseContentType(this.req.headers["Content-Type"])
  let params = contentType[1]
  if params.hasKey("charset"):
    return contentType[1]["charset"]

proc protocol*(this: Request): string =
  return "protocol" # TODO

proc host*(this: Request): string =
  return "host" # TODO

proc hostname*(this: Request): string =
  return "hostname" # TODO

proc origin*(this: Request): string =
  return this.protocol & "://" & this.host # TODO, maybe use Origin header instead

proc href*(this: Request): string =
  return "href" # TODO

proc idempotent*(this: Request): bool =
  return [HttpGet, HttpHead, HttpPut, HttpDelete, HttpOptions, HttpTrace].contains(this.method)

proc get*(this: Request, field: string): string =
  return this.headers.getOrDefault(field)
