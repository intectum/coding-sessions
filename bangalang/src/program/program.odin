package program

import "core:fmt"
import "core:strings"

import "../ast"
import "../parsing"
import "../tokenization"
import "../tokens"

procedure :: struct
{
  statements: [dynamic]ast.node,
  references: [dynamic][dynamic]string,

  identifiers: map[string]ast.node,

  type_checked: bool
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

  identifiers: map[string]ast.node,
  f32_literals: [dynamic]string,
  f64_literals: [dynamic]string,
  string_literals: [dynamic]string,
  cstring_literals: [dynamic]string,
  static_vars: map[string]ast.node,

  queue: [dynamic][dynamic]string
}

init :: proc(program: ^program)
{
  program.identifiers["atomic_i8"] = { type = .type, value = "atomic_i8" }
  program.identifiers["atomic_i16"] = { type = .type, value = "atomic_i16" }
  program.identifiers["atomic_i32"] = { type = .type, value = "atomic_i32" }
  program.identifiers["atomic_i64"] = { type = .type, value = "atomic_i64" }
  program.identifiers["bool"] = { type = .type, value = "bool" }
  program.identifiers["cint"] = { type = .type, value = "cint" }
  program.identifiers["cstring"] = { type = .type, value = "cstring" }
  program.identifiers["cuint"] = { type = .type, value = "cuint" }
  program.identifiers["f32"] = { type = .type, value = "f32" }
  program.identifiers["f64"] = { type = .type, value = "f64" }
  program.identifiers["i8"] = { type = .type, value = "i8" }
  program.identifiers["i16"] = { type = .type, value = "i16" }
  program.identifiers["i32"] = { type = .type, value = "i32" }
  program.identifiers["i64"] = { type = .type, value = "i64" }
  program.identifiers["u8"] = { type = .type, value = "u8" }
  program.identifiers["u16"] = { type = .type, value = "u16" }
  program.identifiers["u32"] = { type = .type, value = "u32" }
  program.identifiers["u64"] = { type = .type, value = "u64" }

  string_type_node := ast.node { type = .type, value = "[slice]" }
  append(&string_type_node.children, ast.node { type = .type, value = "i8" })
  program.identifiers["string"] = string_type_node

  link := ast.node { type = .identifier, value = "link" }
  append(&link.children, ast.node { type = .type, value = "[procedure]" })
  append(&link.children[0].children, ast.node { type = .type, value = "[parameters]" })
  append(&link.children[0].children[0].children, ast.node { type = .identifier, value = "name" })
  append(&link.children[0].children[0].children[0].children, program.identifiers["string"])
  program.identifiers["link"] = link

  import_proc := ast.node { type = .identifier, value = "import" }
  append(&import_proc.children, ast.node { type = .type, value = "[procedure]" })
  append(&import_proc.children[0].children, ast.node { type = .type, value = "[parameters]" })
  append(&import_proc.children[0].children[0].children, ast.node { type = .identifier, value = "name" })
  append(&import_proc.children[0].children[0].children[0].children, program.identifiers["string"])
  append(&import_proc.children[0].children, ast.node { type = .type, value = "[module]" })
  program.identifiers["import"] = import_proc

  cmpxchg := ast.node { type = .identifier, value = "cmpxchg" }
  append(&cmpxchg.children, ast.node { type = .type, value = "[procedure]" })
  append(&cmpxchg.children[0].children, ast.node { type = .type, value = "[parameters]" })
  append(&cmpxchg.children[0].children[0].children, ast.node { type = .identifier, value = "value" })
  append(&cmpxchg.children[0].children[0].children[0].children, ast.node { type = .reference })
  append(&cmpxchg.children[0].children[0].children[0].children[0].children, ast.node { type = .type, value = "i32" })
  append(&cmpxchg.children[0].children[0].children, ast.node { type = .identifier, value = "expected" })
  append(&cmpxchg.children[0].children[0].children[1].children, ast.node { type = .type, value = "i32" })
  append(&cmpxchg.children[0].children[0].children, ast.node { type = .identifier, value = "replacement" })
  append(&cmpxchg.children[0].children[0].children[2].children, ast.node { type = .type, value = "i32" })
  append(&cmpxchg.children[0].children, ast.node { type = .type, value = "bool" })
  program.identifiers["cmpxchg"] = cmpxchg
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
  program.procedures[get_qualified_name({ name })] = { statements = nodes }

  return true
}

get_qualified_name :: proc(path: []string) -> string
{
  final_module_name, _ := strings.replace_all(path[0], "/", ".")
  return strings.concatenate({ final_module_name, ".$module.", strings.join(path[1:], ".") })
}
