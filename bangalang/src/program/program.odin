package program

import "core:fmt"
import "core:strings"

import "../ast"
import "../parsing"
import "../tokenization"
import "../tokens"

reference :: struct
{
  module_name: string,
  procedure_name: string
}

procedure :: struct
{
  statements: [dynamic]ast.node,
  references: [dynamic]reference
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
  static_vars: map[string]ast.node
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
  program.procedures[get_qualified_name(name, "[main]")] = { statements = nodes }

  return true
}

get_qualified_name :: proc(module_name: string, procedure_name: string) -> string
{
  final_module_name, _ := strings.replace_all(module_name, "/", ".")
  return strings.concatenate({ final_module_name, ".$module.", procedure_name })
}
