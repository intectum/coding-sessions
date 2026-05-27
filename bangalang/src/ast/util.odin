package ast

import "core:fmt"
import "core:slice"
import "core:strings"

import "../tokens"

init_root :: proc(root: ^scope)
{
  root.identifiers["atomic_i8"] = make_node({ type = .identifier, value = "atomic_i8" })
  root.identifiers["atomic_i16"] = make_node({ type = .identifier, value = "atomic_i16" })
  root.identifiers["atomic_i32"] = make_node({ type = .identifier, value = "atomic_i32" })
  root.identifiers["atomic_i64"] = make_node({ type = .identifier, value = "atomic_i64" })
  root.identifiers["bool"] = make_node({ type = .identifier, value = "bool" })
  root.identifiers["cint"] = make_node({ type = .identifier, value = "cint" })
  root.identifiers["cuint"] = make_node({ type = .identifier, value = "cuint" })
  root.identifiers["f32"] = make_node({ type = .identifier, value = "f32" })
  root.identifiers["f64"] = make_node({ type = .identifier, value = "f64" })
  root.identifiers["i8"] = make_node({ type = .identifier, value = "i8" })
  root.identifiers["i16"] = make_node({ type = .identifier, value = "i16" })
  root.identifiers["i32"] = make_node({ type = .identifier, value = "i32" })
  root.identifiers["i64"] = make_node({ type = .identifier, value = "i64" })
  root.identifiers["u8"] = make_node({ type = .identifier, value = "u8" })
  root.identifiers["u16"] = make_node({ type = .identifier, value = "u16" })
  root.identifiers["u32"] = make_node({ type = .identifier, value = "u32" })
  root.identifiers["u64"] = make_node({ type = .identifier, value = "u64" })

  allocator_type := make_node({ type = .procedure_type })
  append(&allocator_type.children, make_node({ type = .group, value = "[parameters]" }))

  string_type := make_node({ type = .subscript })
  append(&string_type.children, root.identifiers["u8"])
  range_node := make_node({ type = .range })
  append(&range_node.children, make_node({ type = .nil_literal }))
  append(&range_node.children, make_node({ type = .nil_literal }))
  append(&string_type.children, range_node)

  code_allocator_type := clone_node(allocator_type)
  append(&code_allocator_type.children[0].children, make_node({ type = .assignment_statement }))
  append(&code_allocator_type.children[0].children[0].children, make_node({ type = .identifier, value = "src", data_type = string_type }))
  append(&code_allocator_type.children, string_type)
  root.identifiers["code_allocator"] = code_allocator_type

  memory_allocator_type := clone_node(allocator_type)
  append(&memory_allocator_type.children[0].children, make_node({ type = .assignment_statement }))
  append(&memory_allocator_type.children[0].children[0].children, make_node({ type = .identifier, value = "size", data_type = root.identifiers["u64"] }))
  append(&memory_allocator_type.children, make_node({ type = .reference }))
  append(&memory_allocator_type.children[1].children, root.identifiers["u8"])
  root.identifiers["memory_allocator"] = memory_allocator_type

  nil_allocator_type := clone_node(allocator_type)
  root.identifiers["nil_allocator"] = nil_allocator_type

  static_allocator_type := clone_node(allocator_type)
  append(&static_allocator_type.children, root.identifiers["u64"])
  root.identifiers["static_allocator"] = static_allocator_type

  root.identifiers["code"] = make_node({ type = .identifier, value = "code", data_type = code_allocator_type })
  root.identifiers["extern"] = make_node({ type = .identifier, value = "extern", data_type = nil_allocator_type })
  root.identifiers["none"] = make_node({ type = .identifier, value = "none", data_type = nil_allocator_type })
  root.identifiers["stack"] = make_node({ type = .identifier, value = "stack", data_type = static_allocator_type })
  root.identifiers["static"] = make_node({ type = .identifier, value = "static", data_type = static_allocator_type })
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

get_scope :: proc(root: ^scope, path: []string) -> ^scope
{
  current := root
  for fragment in path
  {
    if !(fragment in current.children) do return nil
    current = &current.children[fragment]
  }

  return current
}

make_node :: proc(init: node = {}) -> ^node
{
  new_node := new(node)
  new_node^ = init
  return new_node
}

clone_node :: proc(root: ^node) -> ^node
{
  clone := make_node(root^)

  if root.data_type != nil
  {
    clone.data_type = clone_node(root.data_type)
  }

  clone.children = {}
  for child in root.children
  {
    append(&clone.children, clone_node(child))
  }

  return clone
}

print_node :: proc(output: ^strings.Builder, root: ^node, indentations: int)
{
  print_indentations(output, indentations)
  fmt.sbprintln(output, "{")
  print_indentations(output, indentations)
  fmt.sbprintf(output, "  \"type\": \"%s\"", root.type)
  if root.value != ""
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    if root.type == .string_literal
    {
      fmt.sbprintf(output, "  \"value\": %s", root.value)
    }
    else
    {
      fmt.sbprintf(output, "  \"value\": \"%s\"", root.value)
    }
  }
  if root.data_type != nil
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    fmt.sbprintln(output, "  \"data_type\":")
    print_node(output, root.data_type, indentations + 1)
  }
  if root.allocator != nil
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    fmt.sbprintln(output, "  \"allocator\":")
    print_node(output, root.allocator, indentations + 1)
  }
  if root.directive != ""
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    fmt.sbprintf(output, "  \"valdirectiveue\": \"%s\"", root.directive)
  }
  if len(root.children) > 0
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    fmt.sbprintln(output, "  \"children\":")
    print_indentations(output, indentations)
    fmt.sbprintln(output, "  [")
    for child, index in root.children
    {
      if index > 0
      {
        fmt.sbprintln(output, ",")
      }
      print_node(output, child, indentations + 2)
    }
    fmt.sbprintln(output, "")
    print_indentations(output, indentations)
    fmt.sbprint(output, "  ]")
  }
  fmt.sbprintln(output, "")
  print_indentations(output, indentations)
  fmt.sbprint(output, "}")
}

print_indentations :: proc(output: ^strings.Builder, indentations: int)
{
  for index in 0..<indentations
  {
    fmt.sbprint(output, "  ")
  }
}

is_import_statement :: proc(statement: ^node) -> bool
{
  if statement.type == .assignment_statement && len(statement.children) > 1
  {
    rhs_node := statement.children[2]
    return rhs_node.type == .call && rhs_node.children[0].value == "import"
  }

  return false
}

is_type_alias_statement :: proc(statement: ^node) -> bool
{
  return statement.type == .assignment_statement && len(statement.children) > 1 && is_type(statement.children[2])
}

is_member :: proc(identifier: ^node) -> bool
{
  if identifier.type != .identifier || len(identifier.children) == 0
  {
    return false
  }

  final_identifier := identifier
  for final_identifier.children[0].type == .dereference || final_identifier.children[0].type == .reference || final_identifier.children[0].type == .subscript
  {
    final_identifier = final_identifier.children[0]
  }

  return final_identifier.children[0].type == .identifier || is_type(final_identifier.children[0])
}

is_type :: proc(type: ^node) -> bool
{
  if type.type == .reference || type.type == .subscript
  {
    return is_type(type.children[0])
  }

  if slice.contains(complex_types, type.type)
  {
    return true
  }

  if type.type == .identifier && slice.contains(simple_types, type.value)
  {
    return true
  }

  return false
}

is_array :: proc(type: ^node) -> bool
{
  return type.type == .subscript && type.children[1].type != .range && is_type(type)
}

is_slice :: proc(type: ^node) -> bool
{
  return type.type == .subscript && type.children[1].type == .range && is_type(type)
}

to_node :: proc(token: tokens.token) -> ^node
{
  return make_node({
    type = to_node_type(token.type),
    value = token.value,
    src_position = token.src_position
  })
}

to_node_type :: proc(token_type: tokens.token_type) -> node_type
{
  #partial switch token_type
  {
  case .ampersand:
    return .bitwise_and
  case .ampersand_equals:
    return .bitwise_and_assign
  case .ampersand_ampersand:
    return .and
  case .asterisk:
    return .multiply
  case .asterisk_equals:
    return .multiply_assign
  case .backslash:
    return .divide
  case .backslash_equals:
    return .divide_assign
  case .closing_angle_bracket:
    return .greater_than
  case .closing_angle_bracket_equals:
    return .greater_than_or_equal
  case .equals:
    return .assign
  case .equals_equals:
    return .equal
  case .exclamation_equals:
    return .not_equal
  case .identifier:
    return .identifier
  case .minus:
    return .subtract
  case .minus_equals:
    return .subtract_assign
  case .opening_angle_bracket:
    return .less_than
  case .opening_angle_bracket_equals:
    return .less_than_or_equal
  case .percent:
    return .modulo
  case .percent_equals:
    return .modulo_assign
  case .pipe:
    return .bitwise_or
  case .pipe_equals:
    return .bitwise_or_assign
  case .pipe_pipe:
    return .or
  case .placeholder:
    return .identifier
  case .plus:
    return .add
  case .plus_equals:
    return .add_assign
  }

  assert(false, "Unsupported node type")
  return .none
}
