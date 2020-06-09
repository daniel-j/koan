import asyncdispatch

import src/koan
import src/koan/logger
import src/koan/sendfile
import src/koan/router

let app = newKoan(proxy = true)

app.use(logger())

let myRouter = Router()

# echo Http308

myRouter.get("/", proc (ctx: Context) {.async.} =
  ctx.status = Http200

  # ctx.type= sets response content-type, in this case to text/html
  #ctx.type = "html"

  # ctx.body= supports strings, streams and asyncfiles
  #ctx.body = "<!doctype html><h1>Hello World</h1>"
  discard await sendfile(ctx, "example.html")
)

app.use(myRouter.routes())

echo "Starting web server..."
waitFor app.listen(Port(8080))
