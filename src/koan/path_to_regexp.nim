# converted from https://github.com/pillarjs/path-to-regexp

import regex
import strutils

type
  LexTokenType = enum ltOpen, ltClose, ltPattern, ltName, ltChar, ltEscapedChar, ltModifier, ltEnd
  LexToken = object
    `type`: LexTokenType
    index: int
    value: string
  Token* = object
    name*: string
    prefix*: string
    suffix*: string
    pattern*: string
    modifier*: string
    path*: string
  Options* = object
    prefixes*: string
    sensitive*: bool
    strict*: bool
    `end`*: bool
    start*: bool
    delimiter*: string
    endsWith*: string
    encode*: proc (value: string): string

proc escapeString(str: string): string =
  return str.replace(re"([.+*?=^!:${}()[\]|/\\])", "\\$1")


proc newOptions(): Options =
  result.strict = false
  result.start = true
  result.end = true
  result.encode = proc (value: string): string = value

proc lexer(str: string): seq[LexToken] =
  var i = 0

  while i < str.len:
    let chr = str[i]

    if chr == '*' or chr == '+' or chr == '?':
      result.add(LexToken(type: ltModifier, index: i, value: $str[i]))
      inc(i)
      continue

    if chr == '\\':
      result.add(LexToken(type: ltEscapedChar, index: i, value: $str[i+1]))
      inc(i, 2)
      continue

    if chr == '{':
      result.add(LexToken(type: ltOpen, index: i, value: $str[i]))
      inc(i)
      continue

    if chr == '}':
      result.add(LexToken(type: ltClose, index: i, value: $str[i]))
      inc(i)
      continue

    if chr == ':':
      var name = "";
      var j = i + 1

      while j < str.len:
        let code = ord(str[j])

        if (
          # `0-9`
          (code >= 48 and code <= 57) or
          # `A-Z`
          (code >= 65 and code <= 90) or
          # `a-z`
          (code >= 97 and code <= 122) or
          # `_`
          code == 95
        ):
          name.add($str[j])
          inc(j)
          continue

        break

      if name.len == 0:
        raise newException(ValueError, "Missing parameter name at " & $i)

      result.add(LexToken(type: ltName, index: i, value: name))
      i = j
      continue

    if chr == '(':
      var count = 1
      var pattern = ""
      var j = i + 1

      if str[j] == '?':
        raise newException(ValueError, "Pattern cannot start with \"?\" at " & $j)

      while j < str.len:
        if str[j] == '\\':
          pattern.add(str[j] & str[j+1])
          inc(j, 2)
          continue

        if str[j] == ')':
          dec(count)
          if count == 0:
            inc(j)
            break
        elif str[j] == '(':
          inc(count)
          if str[j + 1] != '?':
            raise newException(ValueError, "Capturing groups are not allowed at " & $j)

        pattern.add(str[j])
        inc(j)

      if count != 0: raise newException(ValueError, "Unbalanced pattern at " & $i)
      if pattern.len == 0: raise newException(ValueError, "Missing pattern at " & $i)

      result.add(LexToken(type: ltPattern, index: i, value: pattern))
      i = j
      continue

    result.add(LexToken(type: ltChar, index: i, value: $str[i]))
    inc(i)

  result.add(LexToken(type: ltEnd, index: i, value: ""))

proc parse*(str: string, options: Options = Options()): seq[Token] =
  let tokens = lexer(str)
  let prefixes = if options.prefixes.len == 0: "./" else: options.prefixes
  let defaultPattern = "[^" & escapeString(if options.delimiter.len != 0: options.delimiter else: "/#?") & "]+?"
  var key = 0
  var i = 0
  var path = ""

  proc canConsume(`type`: LexTokenType): bool =
    if i < tokens.len and tokens[i].type == type:
      return true
    return false

  proc safeConsume(`type`: LexTokenType, fallback: string = ""): string =
    if canConsume(type):
      result = tokens[i].value
      inc(i)
    else:
      result = fallback

  proc tryConsume(`type`: LexTokenType): (bool, string) =
    result[0] = canConsume(type)
    if result[0]:
      result[1] = safeConsume(type)

  proc mustConsume(`type`: LexTokenType): string =
    if canConsume(type):
      return safeConsume(type)
    else:
      let nextToken = tokens[i]
      raise newException(ValueError, "Unexpected " & $nextToken.type & " at " & $nextToken.index & ", expected " & $type)

  proc consumeText(): string =
    while true:
      var value: string
      if canConsume(ltChar):
        value = safeConsume(ltChar)
      elif canConsume(ltEscapedChar):
        value = safeConsume(ltEscapedChar)
      else:
        break
      result.add(value)

  while i < tokens.len:
    let `char` = safeConsume(ltChar)
    let (hasName, name) = tryConsume(ltName)
    let (hasPattern, pattern) = tryConsume(ltPattern)

    if name.len != 0 or pattern.len != 0:
      var prefix = `char`

      if prefixes.find(prefix) == -1:
        path.add(prefix)
        prefix = ""

      if path.len != 0:
        result.add(Token(path: path))
        path = ""

      result.add(Token(
        name: if hasName: name else: $key,
        prefix: prefix,
        suffix: "",
        pattern: if hasPattern: pattern else: defaultPattern,
        modifier: safeConsume(ltModifier)
      ))
      if not hasName: inc(key)
      continue

    let value = if `char`.len != 0: `char` else: safeConsume(ltEscapedChar)
    if value.len != 0:
      path.add(value)
      continue

    if path.len != 0:
      result.add(Token(path: path))
      path = ""

    let (hasOpen, _) = tryConsume(ltOpen)
    if hasOpen:
      let prefix = consumeText()
      var name = safeConsume(ltName)
      var pattern = safeConsume(ltPattern)
      let suffix = consumeText()

      discard mustConsume(ltClose)

      if name.len == 0:
        if pattern.len != 0:
          name = $key
          inc(key)

      if name.len != 0 and pattern.len == 0:
        pattern = defaultPattern

      result.add(Token(
        name: name,
        pattern: pattern,
        prefix: prefix,
        suffix: suffix,
        modifier: safeConsume(ltModifier)
      ))
      continue

    discard mustConsume(ltEnd)

proc tokensToRegexp*(tokens: seq[Token], keys: ptr seq[Token] = nil, options: Options = newOptions()): Regex =
  let endsWith = "[" & escapeString(options.endsWith) & "]|$"
  let delimiter = "[" & escapeString(if options.delimiter.len != 0: options.delimiter else: "/#?") & "]"
  var route = if options.start: "^" else: ""

  for token in tokens:
    if token.path.len != 0:
      route.add(escapeString(token.path))
    else:
      let prefix = escapeString(options.encode(token.prefix))
      let suffix = escapeString(options.encode(token.suffix))

      if token.pattern.len != 0:
        if not isNil(keys): keys[].add(token)
        if prefix.len != 0 or suffix.len != 0:
          if token.modifier == "+" or token.modifier == "*":
            let modifier = if token.modifier == "*": "?" else: ""
            route.add("(?:" & prefix & "((?:" & token.pattern & ")(?:" & suffix & prefix & "(?:" & token.pattern & "))*)" & suffix & ")" & modifier)
          else:
            route.add("(?:" & prefix & "(" & token.pattern & ")" & suffix & ")" & token.modifier)
        else:
          route.add("(" & token.pattern & ")" & token.modifier)
      else:
        route.add("(?:" & prefix & suffix & ")" & token.modifier)

  if options.end:
    if not options.strict:
      route.add(delimiter & "?")
    route.add(if options.endsWith.len == 0: "$" else: "(?=" & endsWith & ")")
  else:
    var isEndDelimited = tokens.len == 0
    if tokens.len > 0:
      let endToken = tokens[tokens.len - 1]
      if endToken.path.len != 0:
        isEndDelimited = delimiter.find(endToken.path[endToken.path.len - 1]) > -1

    if not options.strict:
      route.add("(?:" & delimiter & "(?=" & endsWith & "))?")

    if not isEndDelimited:
      route.add("(?=" & delimiter & "|" & endsWith & ")")

  echo route
  return re((if not options.sensitive: "(?i)" else: "") & route)

proc stringToRegexp(path: string, keys: ptr seq[Token] = nil, opts: Options = newOptions()): Regex =
  return tokensToRegexp(parse(path, opts), keys, opts)

proc pathToRegexp*(path: string, keys: ptr seq[Token] = nil, opts: Options = newOptions()): Regex =
  return stringToRegexp(path, keys, opts)
