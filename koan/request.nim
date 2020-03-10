
from parseutils import parseInt

proc `method`*(this: Request): string =
  return $this.req.reqMethod

proc length*(this: Request): int =
  result = -1
  if this.headers.hasKey("Content-Length"):
    discard parseInt(this.headers["Content-Length"], result)

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
