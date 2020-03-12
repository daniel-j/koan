import asyncdispatch

import src/koan
import src/koan/logger
import src/koan/sendfile

let app = Koan()

app.use(logger())

app.use(proc (ctx: Context) {.async.} =
  #ctx.status = 200

  # ctx.type= sets response content-type, in this case to text/html
  #ctx.type = "html"

  # ctx.body= supports strings and streams
  #ctx.body = "<!doctype html><h1>Hello World</h1>"
  discard await sendfile(ctx, "example.html")
)

echo "Starting web server..."
waitFor app.listen(Port(8080))
