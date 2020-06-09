import httpcore

when not declared(Http308):
  const Http308 = HttpCode(308)

proc isRedirect*(code: HttpCode): bool =
  return code in [Http300, Http301, Http302, Http303, Http305, Http307, Http308]

proc isEmpty*(code: HttpCode): bool =
  return code in [Http204, Http205, Http304]

proc isRetry*(code: HttpCode): bool =
  return code in [Http502, Http503, Http504]
