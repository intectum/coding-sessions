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
  imports: map[string][2]string,

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

  import_proc := ast.node { type = .identifier, value = "import", allocator = "none" }
  append(&import_proc.children, ast.node { type = .type, value = "[procedure]" })
  append(&import_proc.children[0].children, ast.node { type = .type, value = "[parameters]" })
  append(&import_proc.children[0].children[0].children, ast.node { type = .assignment_statement })
  append(&import_proc.children[0].children[0].children[0].children, ast.node { type = .identifier, value = "module" })
  append(&import_proc.children[0].children[0].children[0].children[0].children, program.identifiers["string"])
  append(&import_proc.children[0].children[0].children, ast.node { type = .assignment_statement })
  append(&import_proc.children[0].children[0].children[1].children, ast.node { type = .identifier, value = "lib" })
  append(&import_proc.children[0].children[0].children[1].children[0].children, program.identifiers["string"])
  append(&import_proc.children[0].children[0].children[1].children, ast.node { type = .assign, value = "=" })
  append(&import_proc.children[0].children[0].children[1].children, ast.node { type = .string_literal, value = "\"\"" })
  append(&import_proc.children[0].children, ast.node { type = .type, value = "[module]" })
  program.identifiers["import"] = import_proc
}

load_module :: proc(program: ^program, path: []string, code: string) -> bool
{
  qualified_module_name := get_qualified_module_name(path)
  if qualified_module_name in program.modules
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

  program.modules[qualified_module_name] = {}
  program.procedures[qualified_module_name] = { statements = nodes }

  return true
}

get_qualified_name :: proc(path: []string) -> string
{
  qualified_name := get_qualified_module_name(path)

  if len(path) > 2
  {
    qualified_name = strings.concatenate({ qualified_name, ".", strings.join(path[2:], ".") })
  }

  return qualified_name
}

get_qualified_module_name :: proc(path: []string) -> string
{
  final_module_name, _ := strings.replace_all(path[1], "/", ".")
  qualified_module_name := strings.concatenate({ final_module_name, ".$module" })

  if path[0] == "[main]"
  {
    return qualified_module_name
  }

  final_lib_name, _ := strings.replace_all(path[0], "/", ".")
  return strings.concatenate({ final_lib_name, ".$lib.", qualified_module_name })
}
