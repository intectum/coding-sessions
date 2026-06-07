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
  statements := load_code(readable_name, code) or_return

  if !(path[0] in program.children)
  {
    new_lib := new(ast.scope)
    new_lib.path = path[0:1]
    program.children[path[0]] = new_lib
  }

  new_module := new(ast.scope)
  new_module.path = path
  new_module.statements = statements

  lib := program.children[path[0]]
  lib.children[path[1]] = new_module

  return true
}

load_code :: proc(name: string, code: string) -> (nodes: [dynamic]^ast.node, ok: bool)
{
  tokenization_result := tokenization.tokenize(name, code) or_return

  ctx: parsing.parsing_context = { true }
  stream := tokens.stream { tokens = tokenization_result[:] }

  for stream.next_index < len(stream.tokens)
  {
    statement_node, statement_ok := parsing.parse_statement(&ctx, &stream)
    if !statement_ok
    {
      fmt.println(stream.error)
      return {}, false
    }

    append(&nodes, statement_node)
  }

  return nodes, true
}
