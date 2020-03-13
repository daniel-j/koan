import uri
import parseutils
import strutils
import httpcore
import tables

import util

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
  return this.protocol & "://" & this.host

proc href*(this: Request): string =
  return "href" # TODO

proc fresh*(this: Request): bool =
  # TODO: Test this
  result = false
  if [HttpGet, HttpHead].contains(this.method):
    let s = Context(this).status
    if (s >= 200 and s < 300) or s == 304:
      return fresh(this.headers, Response(this).headers)

proc stale*(this: Request): bool =
  return not this.fresh

proc idempotent*(this: Request): bool =
  return [HttpGet, HttpHead, HttpPut, HttpDelete, HttpOptions, HttpTrace].contains(this.method)

proc get*(this: Request, field: string): string =
  return this.headers.getOrDefault(field)
