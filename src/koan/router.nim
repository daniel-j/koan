import httpcore
import tables
import asyncdispatch
import strutils

import ../koan
import path_to_regexp
import nre except toSeq
from uri import decodeUrl

type

  LayerOptions = object
    `end`: bool
    name: string
    sensitive: bool
    strict: bool
    prefix: string
    ignoreCaptures: bool

  Layer = object
    name: string
    path: string
    methods: seq[HttpMethod]
    options: LayerOptions
    paramNames: seq[Token]
    stack: seq[Middleware]
    regexp: Regex

  Router* = ref object
    stack: seq[Layer]
    params: Table[string, string]

proc newLayer(path: string, methods: seq[HttpMethod], middlewares: seq[Middleware], opts: LayerOptions = LayerOptions()): Layer =
  result.options = opts
  result.name = result.options.name
  result.stack = middlewares

  for i in 0 ..< methods.len:
    result.methods.add(methods[i])
    if result.methods[result.methods.len - 1] == HttpGet:
      result.methods.insert(HttpHead, 0)

  result.path = path
  result.regexp = pathToRegexp(path, result.paramNames.addr)

proc params(this: Layer, path: string): Table[string, string] =
  var i = 0
  for match in path.findIter(this.regexp):
    if i < this.paramNames.len:
      let token = this.paramNames[i]
      inc(i)
      result[token.name] = decodeUrl(match.captures[0], false)


proc register(this: Router, path: string, methods: seq[HttpMethod], middlewares: seq[Middleware], opts: LayerOptions = LayerOptions()): Router {.discardable.} =
  result = this

  let route = newLayer(path, methods, middlewares, opts)
  # echo "params: ", route.params("/hello/12%20+hello")


template setMethodVerb(methodName: untyped, `method`: HttpMethod) =
  proc `methodName`*(this: Router, name: string, path: string, middlewares: varargs[Middleware, convertMiddleware]): Router {.discardable.} =
    result = this
    if len(middlewares) == 0: return
    for m in middlewares:
      this.register(path, @[`method`], @[m], LayerOptions(name: name))

  proc `methodName`*(this: Router, path: string, middlewares: varargs[Middleware, convertMiddleware]): Router {.discardable.} =
    result = this
    if len(middlewares) == 0: return
    for m in middlewares:
      this.register(path, @[`method`], @[m])

setMethodVerb(get, HttpGet)
setMethodVerb(post, HttpPost)
setMethodVerb(put, HttpPut)
setMethodVerb(delete, HttpDelete)


proc routes*(this: Router): Middleware =
  return proc (ctx: Context, next: Next) {.async.} =
    echo "MIDDLEWARE"