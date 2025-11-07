package program

import "core:fmt"
import "core:strings"

import "../ast"
import "../parsing"
import "../tokenization"
import "../tokens"

procedure :: struct
{
  statements: [dynamic]^ast.node,
  references: [dynamic][dynamic]string,

  identifiers: map[string]^ast.node,

  type_checked: bool
}

module :: struct
{
  imports: map[string][2]string,

  identifiers: map[string]^ast.node
}

program :: struct
{
  modules: map[string]module,
  procedures: map[string]procedure,
  links: [dynamic]string,

  identifiers: map[string]^ast.node,
  f32_literals: [dynamic]string,
  f64_literals: [dynamic]string,
  string_literals: [dynamic]string,
  cstring_literals: [dynamic]string,
  static_vars: map[string]^ast.node,

  queue: [dynamic][dynamic]string
}

init :: proc(program: ^program)
{
  program.identifiers["atomic_i8"] = ast.make_node({ type = .type, value = "atomic_i8" })
  program.identifiers["atomic_i16"] = ast.make_node({ type = .type, value = "atomic_i16" })
  program.identifiers["atomic_i32"] = ast.make_node({ type = .type, value = "atomic_i32" })
  program.identifiers["atomic_i64"] = ast.make_node({ type = .type, value = "atomic_i64" })
  program.identifiers["bool"] = ast.make_node({ type = .type, value = "bool" })
  program.identifiers["cint"] = ast.make_node({ type = .type, value = "cint" })
  program.identifiers["cstring"] = ast.make_node({ type = .type, value = "cstring" })
  program.identifiers["cuint"] = ast.make_node({ type = .type, value = "cuint" })
  program.identifiers["f32"] = ast.make_node({ type = .type, value = "f32" })
  program.identifiers["f64"] = ast.make_node({ type = .type, value = "f64" })
  program.identifiers["i8"] = ast.make_node({ type = .type, value = "i8" })
  program.identifiers["i16"] = ast.make_node({ type = .type, value = "i16" })
  program.identifiers["i32"] = ast.make_node({ type = .type, value = "i32" })
  program.identifiers["i64"] = ast.make_node({ type = .type, value = "i64" })
  program.identifiers["u8"] = ast.make_node({ type = .type, value = "u8" })
  program.identifiers["u16"] = ast.make_node({ type = .type, value = "u16" })
  program.identifiers["u32"] = ast.make_node({ type = .type, value = "u32" })
  program.identifiers["u64"] = ast.make_node({ type = .type, value = "u64" })

  allocator_type := ast.make_node({ type = .type, value = "[procedure]" })
  append(&allocator_type.children, ast.make_node({ type = .type, value = "[parameters]" }))

  string_type := ast.make_node({ type = .type, value = "[slice]" })
  append(&string_type.children, program.identifiers["u8"])

  code_allocator_type := ast.clone_node(allocator_type)
  append(&code_allocator_type.children[0].children, ast.make_node({ type = .assignment_statement }))
  append(&code_allocator_type.children[0].children[0].children, ast.make_node({ type = .identifier, value = "src", data_type = string_type }))
  append(&code_allocator_type.children, string_type)
  program.identifiers["code_allocator"] = code_allocator_type

  memory_allocator_type := ast.clone_node(allocator_type)
  append(&memory_allocator_type.children[0].children, ast.make_node({ type = .assignment_statement }))
  append(&memory_allocator_type.children[0].children[0].children, ast.make_node({ type = .identifier, value = "size", data_type = program.identifiers["i64"] }))
  append(&memory_allocator_type.children, ast.make_node({ type = .reference }))
  append(&memory_allocator_type.children[1].children, program.identifiers["u8"])
  program.identifiers["memory_allocator"] = memory_allocator_type

  nil_allocator_type := ast.clone_node(allocator_type)
  program.identifiers["nil_allocator"] = nil_allocator_type

  static_allocator_type := ast.clone_node(allocator_type)
  append(&static_allocator_type.children, program.identifiers["i64"])
  program.identifiers["static_allocator"] = static_allocator_type

  program.identifiers["code"] = ast.make_node({ type = .identifier, value = "code", data_type = code_allocator_type })
  program.identifiers["extern"] = ast.make_node({ type = .identifier, value = "extern", data_type = nil_allocator_type })
  program.identifiers["none"] = ast.make_node({ type = .identifier, value = "none", data_type = nil_allocator_type })
  program.identifiers["stack"] = ast.make_node({ type = .identifier, value = "stack", data_type = static_allocator_type })
  program.identifiers["static"] = ast.make_node({ type = .identifier, value = "static", data_type = static_allocator_type })
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
