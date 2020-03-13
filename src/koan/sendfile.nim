import asyncdispatch
import os
import streams
import httpcore

import ../koan


proc sendfile*(ctx: Context, path: string): Future[FileInfo] {.async.} =
  result = getFileInfo(path) # FIXME: BLOCKING
  if result.kind != pcFile: raise newException(OSError, "Input path is not a file")

  ctx.response.status = 200
  ctx.response.lastModified = result.lastWriteTime
  ctx.response.length = result.size
  ctx.response.type = splitFile(path).ext
  # TODO: Add etag support here

  # TODO: Add support for fresh
  if ctx.request.fresh:
    ctx.response.status = 304
    return
  if ctx.request.method == HttpHead:
    return
  
  ctx.body = openFileStream(path)
