import macros

macro getName*(x: typed, default:string = ""): string =
  if x.kind == nnkSym:
    newLit x.getImpl[0].strVal
  else:
    newLit default.strVal
