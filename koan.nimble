# Package

version       = "0.1.0"
author        = "djazz"
description   = "Nim port of the KoaJS web server framework"
license       = "MIT"
srcDir        = "src"

# Dependencies

requires "nim >= 1.0.0"
requires "regex >= 0.15.0"

task example, "Run example":
  exec "nim c -r example.nim"
