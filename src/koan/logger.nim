import asyncdispatch
from times import cpuTime
from math import round
from util import humanizeNumber, bytes
import terminal
import httpcore

import ./middleware
import ./statuses

proc time(start: float): string =
  let delta = cpuTime() - start
  if delta < 10:
    result = humanizeNumber(round(delta * 1000)) & " ms"
  else:
    result = humanizeNumber(round(delta)) & " s"

proc logger*(): auto =
  return proc (ctx: Context) {.async.} =
    let start = cpuTime()

    styledEcho(
      "  ",
      styleBright, fgBlack, "<--", resetStyle,
      " ",
      styleBright, $ctx.method, resetStyle,
      " ",
      styleBright, fgBlack, ctx.originalUrl
    )

    await ctx.next()

    let statusColor = case int(ctx.status.int / 100):
      of 7: fgMagenta
      of 5: fgRed
      of 4: fgYellow
      of 3: fgCyan
      of 2: fgGreen
      of 1: fgGreen
      else: fgYellow

    let length =
      if ctx.status.isEmpty: ""
      elif ctx.length == -1: "-"
      else: bytes(ctx.length)

    styledEcho(
      "  ",
      styleBright, fgBlack, "-->", resetStyle,
      " ",
      styleBright, $ctx.method, resetStyle,
      " ",
      styleBright, fgBlack, ctx.originalUrl, resetStyle,
      " ",
      statusColor, $ctx.status, resetStyle,
      " ",
      styleBright, fgBlack, time(start), resetStyle,
      " ",
      styleBright, fgBlack, length
    )
