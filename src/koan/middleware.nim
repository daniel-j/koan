import asyncdispatch

import ./context
export context

type
  Middleware* = proc (ctx: Context): Future[void] {.gcsafe.}

# use this with varargs as second argument, or you may get an ugly error
proc convertMiddleware*(middleware: Middleware): Middleware = middleware
