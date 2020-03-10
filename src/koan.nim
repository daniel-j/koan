import asyncdispatch
import httpcore
from asynchttpserver as http import nil
from asyncnet import send, close
from uri import `$`

import koan/util
include koan/[types, response, request, compose]

proc use*(this: Koan, name: string, callback: Middleware): auto {.discardable.} =
  echo "use ", if name != "": name else: "-"
  this.middleware.add(callback)
  return this
proc use*(this: Koan, name: string, callback: MiddlewareSimple): auto {.discardable.} =
  this.use(name, proc(ctx: Context, next: Next): auto = return callback(ctx))

template use*(this: Koan, callback: Middleware): untyped =
  this.use(getName(callback), callback)
template use*(this: Koan, callback: MiddlewareSimple): untyped =
  this.use(getName(callback), callback)

proc respond(this: Koan, ctx: Context) {.async.} =
  var content = ""
  if isNil(ctx.response.body):
    content = if ctx.response.message != "": ctx.response.message else: $(ctx.response.status)
    ctx.length = len(content)
  else:
    case ctx.response.body.kind:
      of bkString:
        content = ctx.response.body.strVal
      else: discard

  echo "HTTP CODE: " & $ctx.response.status
  echo "HEADERS: " & $ctx.response.headers
  echo "BODY: " & content
  
  var msg = "HTTP/1.1 " & $HttpCode(ctx.response.status) & "\c\L"
  for k, v in ctx.response.headers:
    msg.add(k & ": " & v & "\c\L")
  msg.add("\c\L")
  await ctx.socket.send(msg)
  await ctx.socket.send(content)
  ctx.socket.close()

proc createContext(this: Koan, req: http.Request): auto =
  let ctx = Context()
  let request = Request(req: req)
  let response = Response(ctx)
  ctx.app = this
  ctx.request = request
  ctx.response = response

  request.url = $req.url
  request.headers = req.headers

  response.socket = req.client
  response.headers = newHttpHeaders()
  response.status = 404
  return ctx

proc handleRequest(this: Koan, ctx: Context, fnMiddleware: Middleware) {.async.} =
  echo "Incoming request: " & $ctx.request.req
  try:
    await fnMiddleware(ctx)
  except KoanException:
    echo "Middleware exception:"
    echo getCurrentException().msg
  await this.respond(ctx)

proc callback*(this: Koan): auto =
  let fn = compose(this.middleware)
  return proc (req: http.Request) {.async, gcsafe.} =
    let ctx = this.createContext(req)
    await this.handleRequest(ctx, fn)

proc listen*(this: Koan, port: Port, address = ""): auto =
  let server = http.newAsyncHttpServer()
  return http.serve(server, port, this.callback(), address)
