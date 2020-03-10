
import httpcore
from streams import Stream
from strutils import split
from parseutils import parseInt
from mimetypes import newMimetypes, getMimetype

# Headers
proc get*(this: Response, field: string): auto =
  return this.headers[field]
proc set*(this: Response, field: string, value: string) =
  this.headers[field] = value
proc append*(this: Response, field: string, value: string) =
  this.headers.add(field, value)
proc has*(this: Response, field: string): bool =
  return this.headers.hasKey(field)
proc remove*(this: Response, field: string) =
  this.headers.del(field)

# Length
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
proc `length=`*(this: Response, n:int) =
  this.set("Content-Length", $(n))

# Type
proc type*(this: Response): string =
  let t = this.get("Content-Type")
  return t.split(";", 1)[0]
proc `type=`*(this: Response, value: string) =
  let m = newMimetypes() # TODO: Reuse instance?
  let t = m.getMimetype(value, default = "")
  # TODO: Add charset support!
  if t != "":
    this.set("Content-Type", t)
  else:
    this.remove("Content-Type")

# Body
proc body*(this: Response): Body = this.body
proc `body=`*(this: Response, val: string) =
  this.body = Body(kind: bkString, strVal: val)
  this.length = len(val)
proc `body=`*(this: Response, val:Stream) =
  if isNil(val):
    this.body = nil
    this.length = -1
    this.remove("Content-Length")
    this.remove("Content-Type")
    this.remove("Transfer-Encoding")
  else:
    this.body = Body(kind: bkStream, streamVal: val)
    this.length = -1
