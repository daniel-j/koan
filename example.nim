import asyncdispatch

import src/koan
import src/koan/logger
import src/koan/sendfile
import src/koan/router

let app = Koan()

app.use(logger())

let myRouter = Router()

myRouter.get("/hello/:world", proc (ctx: Context) {.async.} =
  #ctx.status = 200

  # ctx.type= sets response content-type, in this case to text/html
  #ctx.type = "html"

  # ctx.body= supports strings and streams
  #ctx.body = "<!doctype html><h1>Hello World</h1>"
  discard await sendfile(ctx, "example.html")
)

app.use(myRouter.routes())

echo "Starting web server..."
waitFor app.listen(Port(8080))
