package loading

import "core:fmt"
import "core:strings"

import "../ast"
import "../parsing"
import "../tokenization"
import "../tokens"

load_module :: proc(program: ^ast.scope, path: []string, code: string) -> bool
{
  if path[0] in program.children && path[1] in program.children[path[0]].children
  {
    return true
  }

  readable_name := strings.concatenate({ path[0], ":", path[1] })
  tokenization_result := tokenization.tokenize(readable_name, code) or_return

  stream := tokens.stream { tokens = tokenization_result[:] }
  nodes, parse_ok := parsing.parse_module(&stream)
  if !parse_ok
  {
    fmt.println(stream.error)
    return false
  }

  if !(path[0] in program.children)
  {
    new_lib := new(ast.scope)
    new_lib.path = path[0:1]
    program.children[path[0]] = new_lib
  }

  new_module := new(ast.scope)
  new_module.path = path
  new_module.statements = nodes

  lib := program.children[path[0]]
  lib.children[path[1]] = new_module

  return true
}
