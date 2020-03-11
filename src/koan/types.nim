
import asyncdispatch # Future
import streams # Stream
import asynchttpserver # Request
import httpcore # HttpHeaders
import asyncnet # AsyncSocket

type
  KoanException* = object of Exception

  BodyKind = enum bkString, bkStream
  Body = ref object of RootObj
    case kind: BodyKind
    of bkString: strVal: string
    of bkStream: streamVal: Stream

  Request = ref object of RootObj
    req*: asynchttpserver.Request
    url*: string
    headers*: HttpHeaders

  Response* = ref object of RootObj
    body: Body
    headers*: HttpHeaders
    status*: range[0..599]
    message*: string
    socket*: AsyncSocket

  Context* = ref object of Response
    app*: Koan
    request*: Request
    response*: Response

  Next* = proc(): Future[void] {.gcsafe.}
  Middleware* = proc (ctx: Context, next: Next = nil): Future[void] {.gcsafe.}
  MiddlewareSimple* = proc (ctx: Context): Future[void] {.gcsafe.}

  Koan* = ref object of RootObj
    middleware: seq[Middleware]

include request, response
