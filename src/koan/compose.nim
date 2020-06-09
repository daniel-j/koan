import asyncdispatch
from system import newException

import ./middleware

proc compose*(middleware: seq[Middleware]): Middleware =
  return proc (ctx: Context) {.async.} =
    var index = -1
    proc dispatch(i: int) {.async.} =
      if i <= index: raise newException(CatchableError, "next() called multiple times")
      index = i
      if i != len(middleware):
        ctx.next = proc() {.async.} = await dispatch(i + 1)
        await middleware[i](ctx)
    await dispatch(0)
