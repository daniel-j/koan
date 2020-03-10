import asyncdispatch
from times import cpuTime
import ../koan

proc logger(ctx: Context, next: Next) {.async.} =
  echo ctx.request.length
  let time = cpuTime()
  await next()
  let ms = cpuTime() - time
  echo ctx.request.method & " " & ctx.request.url & " " & $(ms)
