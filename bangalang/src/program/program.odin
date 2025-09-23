package program

import "core:fmt"

import "../ast"
import "../parsing"
import "../tokenization"
import "../tokens"

procedure :: struct
{
  statements: [dynamic]ast.node,
  references: [dynamic]string
}

module :: struct
{
  imports: map[string]string,
  identifiers: map[string]ast.node
}

program :: struct
{
  modules: map[string]module,
  procedures: map[string]procedure,
  links: [dynamic]string,

  f32_literals: [dynamic]string,
  f64_literals: [dynamic]string,
  string_literals: [dynamic]string,
  cstring_literals: [dynamic]string,
  static_vars: map[string]string
}

load_module :: proc(program: ^program, name: string, code: string) -> bool
{
  if name in program.modules
  {
    return true
  }

  tokenization_result := tokenization.tokenize(name, code) or_return

  stream := tokens.stream { tokens = tokenization_result[:] }
  nodes, parse_ok := parsing.parse_module(&stream)
  if !parse_ok
  {
    fmt.println(stream.error)
    return false
  }

  program.modules[name] = {}
  program.procedures[name] = { statements = nodes }

  return true
}
