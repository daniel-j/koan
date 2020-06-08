
import httpcore
import streams # Stream
import strutils # split
import parseutils # parseInt
import times
import options
export options.isNone, options.isSome, options.get

from util import getType

# Headers
proc get*(this: Response, field: string): auto = return this.headers[field]
proc set*(this: Response, field: string, value: string) = this.headers[field] = value
proc append*(this: Response, field: string, value: string) = this.headers.add(field, value)
proc has*(this: Response, field: string): bool = return this.headers.hasKey(field)
proc remove*(this: Response, field: string) = this.headers.del(field)

# Content Length
proc length*(this: Response): int =
  result = -1
  if this.headers.hasKey("Content-Length"):
    discard parseInt(this.headers["Content-Length"], result)
  elif not isNil(this.body):
    case this.body.kind:
      of bkString:
        result = len(this.body.strVal)
      else:
        result = -1
proc `length=`*(this: Response, n:int|BiggestInt) =
  if n >= 0:
    this.set("Content-Length", $(n))
  else:
    this.remove("Content-Length")

# Content Type
proc type*(this: Response): string =
  result = this.get("Content-Type")
  result = result.split(";", 1)[0]
proc `type=`*(this: Response, value: string) =
  let t = getType(value)
  if t == "":
    this.remove("Content-Type")
  else:
    this.set("Content-Type", t)

# Last Modified
proc lastModified*(this: Response): Option[DateTime] =
  if this.has("Last-Modified"):
    return some(parseLastModified(this.get("Last-Modified")))
proc `lastModified=`*(this: Response, lastmod: DateTime|Time) =
  this.set("Last-Modified", formatLastModified(lastmod))
proc `lastModified=`*(this: Response, lastmod: type(nil)) =
  this.remove("Last-Modified")

# Body
proc body*(this: Response): Body = this.body
proc `body=`*(this: Response, val: string) =
  this.body = Body(kind: bkString, strVal: val)
  this.length = len(val)
proc `body=`*(this: Response, val: type(nil)) =
  this.body = nil
  this.remove("Content-Length")
  this.remove("Content-Type")
  this.remove("Transfer-Encoding")
proc `body=`*(this: Response, val: Stream) =
  this.body = Body(kind: bkStream, streamVal: val)
proc `body=`*(this: Response, val: AsyncFile) =
  this.body = Body(kind: bkAsyncFile, asyncFileVal: val)
  this.length = getFileSize(val)
