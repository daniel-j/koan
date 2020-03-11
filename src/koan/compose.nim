
from system import newException

proc compose*(middleware: seq[Middleware]): Middleware =
  return proc (ctx: Context, next: Next = nil) {.async.} =
    var index = -1
    proc dispatch(i: int) {.async.} =
      if i <= index: raise newException(KoanException, "next() called multiple times")
      index = i
      if i != len(middleware):
        await middleware[i](ctx, proc() {.async.} = await dispatch(i + 1))
    await dispatch(0)
