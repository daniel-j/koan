
import asyncdispatch # Future
import streams # Stream
import httpcore # HttpHeaders
import asyncnet # AsyncSocket

type
  KoanException* = object of Exception

  Next* = proc(): Future[void] {.gcsafe.}
  Middleware* = proc (ctx: Context, next: Next = nil): Future[void] {.gcsafe.}
  MiddlewareSimple* = proc (ctx: Context): Future[void] {.gcsafe.}

  Koan* = ref object of RootObj
    middleware: seq[Middleware]

  BodyKind = enum bkString, bkStream
  Body = ref object of RootObj
    case kind: BodyKind
    of bkString: strVal: string
    of bkStream: streamVal: Stream

  Request = ref object of RootObj
    req*: http.Request
    url*: string

  Response* = ref object of Request
    socket*: AsyncSocket
    status*: range[0..599]
    headers*: HttpHeaders
    message*: string
    body: Body

  Context* = ref object of Response
    app*: Koan
    request*: Request
    response*: Response

include request, response, context
