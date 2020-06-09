import asyncdispatch

import ./app
import ./request
import ./response

export response

type
  Next* = proc(): Future[void] {.gcsafe.}

  Context* = ref object of Response
    app*: App
    request*: Request
    response*: Response
    respond*: bool
    next*: Next

# TODO: Add cookies support
