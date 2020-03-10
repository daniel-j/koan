
import asyncdispatch
import koan

include koan/logger

let app = Koan()

app.use(logger)

app.use(proc (ctx: Context, next: Next) {.async.} =
  ctx.type = "html"
  ctx.status = 200
  ctx.body = "<!doctype html><h1>Hello World</h1>"
)

echo "Starting web server..."
waitFor app.listen(Port(8080))
