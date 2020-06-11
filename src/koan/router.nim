import httpcore
import tables
import asyncdispatch
import regex
import uri
import sequtils

import ./middleware
import ./path_to_regexp

type
  ParamsArg = openArray[(string, string)]
  Params = Table[string, string]

  RouterContext* = ref object of Context
    captures*: seq[string]
    params*: Params
    routerName*: string

  ParamMiddleware = proc (name: string, ctx: Context): Middleware

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
    opts: LayerOptions
    paramNames: seq[Token]
    stack: seq[Middleware]
    regexp: Regex

  Matched = object
    path: seq[Layer]
    pathAndMethod: seq[Layer]
    route: bool

  Router* = ref object
    stack: seq[Layer]
    params: Table[string, ParamMiddleware]

proc newLayer(path: string, methods: seq[HttpMethod], middlewares: seq[Middleware], opts: LayerOptions = LayerOptions()): Layer =
  result.opts = opts
  result.name = result.opts.name
  result.stack = middlewares

  for i in 0 ..< methods.len:
    result.methods.add(methods[i])
    if result.methods[result.methods.len - 1] == HttpGet:
      result.methods.insert(HttpHead, 0)

  result.path = path
  result.regexp = pathToRegexp(path, result.paramNames.addr)


proc match(this: Layer, path: string): bool = path.match(this.regexp)

proc params(this: Layer, path: string, captures: seq[string], existingParams: ParamsArg = {:}): Params =
  result = existingParams.toTable
  for i, c in captures:
    if i < this.paramNames.len:
      result[this.paramNames[i].name] = decodeUrl(c, false)

proc captures(this: Layer, path: string): seq[string] =
  if not this.opts.ignoreCaptures:
    var m: RegexMatch
    if path.match(this.regexp, m):
      for i in 0 ..< m.groupsCount():
        result.add(path[m.group(i)[0]])

proc url*(this: Layer, params: ParamsArg, query: openArray[(string, string)] = {:}, options: path_to_regexp.Options = path_to_regexp.newOptions()): string =
  let url = this.path.replace(re"\(\.\*\)", "")
  let toPath = compile(url, options)

  result = toPath(params.toTable)

  if query.len != 0:
    var replaced = parseUri(result)
    replaced.query = encodeQuery(query)
    result = $replaced

proc param(this: Layer, param: string, fn: ParamMiddleware): Layer =
  result = this
  let params = this.paramNames
  let middleware = proc (ctx: Context): Middleware =
    return fn(RouterContext(ctx).params[param], ctx)

  let names = params.map(proc (p: Token): string =
    return p.name
  )

  let x = names.find(param)

  if x > -1:
    for i, fn in this.stack:
      # TODO
      discard


proc register(this: Router, path: string, methods: seq[HttpMethod], middlewares: seq[Middleware], opts: LayerOptions = LayerOptions()): Router {.discardable.} =
  result = this

  let route = newLayer(path, methods, middlewares, opts)
  echo route.url({"world": "1234", "0": "123"}, query={"hello": "world"})
  # echo "params: ", route.params("/hello/12%20+hello")

template setMethodVerb(methodName: untyped, `method`: HttpMethod) =
  proc `methodName`*(this: Router, name: string, path: string, middleware: varargs[Middleware, convertMiddleware]): Router {.discardable.} =
    result = this
    if len(middleware) == 0: return
    this.register(path, @[`method`], @middleware, LayerOptions(name: name))

  proc `methodName`*(this: Router, path: string, middleware: varargs[Middleware, convertMiddleware]): Router {.discardable.} =
    result = this
    if len(middleware) == 0: return
    this.register(path, @[`method`], @middleware)

setMethodVerb(get, HttpGet)
setMethodVerb(post, HttpPost)
setMethodVerb(put, HttpPut)
setMethodVerb(delete, HttpDelete)


proc routes*(this: Router): Middleware =
  return proc (ctx: Context) {.async.} =
    echo "MIDDLEWARE"

proc middleware*(this: Router): auto = this.routes()

proc match*(this: Router, path: string, `method`: HttpMethod): Matched =
  let layers = this.stack

  for layer in layers:
    if layer.match(path):
      result.path.add(layer)

      if layer.methods.len == 0 or layer.methods.find(`method`) != -1:
        result.pathAndMethod.add(layer)
        if layer.methods.len != 0: result.route = true

proc param*(this: Router, param: string, middleware: ParamMiddleware): Router =
  result = this
  this.params[param] = middleware
  for layer in this.stack:
    discard layer.param(param, middleware)