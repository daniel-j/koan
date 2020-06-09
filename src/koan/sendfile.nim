import asyncdispatch
import os
import asyncfile
import httpcore

import ./context

proc sendfile*(ctx: Context, path: string): Future[FileInfo] {.async.} =
  result = getFileInfo(path) # FIXME: BLOCKING
  if result.kind != pcFile: raise newException(OSError, "Input path is not a file")

  ctx.response.status = Http200
  ctx.response.lastModified = result.lastWriteTime
  ctx.response.length = result.size
  ctx.response.type = splitFile(path).ext
  # TODO: Add etag support here

  if ctx.request.fresh:
    ctx.response.status = Http304
    return
  if ctx.request.method == HttpHead:
    return

  ctx.body = openAsync(path)
