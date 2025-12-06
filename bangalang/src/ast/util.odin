package ast

import "core:slice"
import "core:strings"

import "../tokens"

to_path_name :: proc(path: []string) -> string
{
  return strings.join(path, ":")
}

init_root :: proc(root: ^scope)
{
  root.identifiers["atomic_i8"] = make_node({ type = .type, value = "atomic_i8" })
  root.identifiers["atomic_i16"] = make_node({ type = .type, value = "atomic_i16" })
  root.identifiers["atomic_i32"] = make_node({ type = .type, value = "atomic_i32" })
  root.identifiers["atomic_i64"] = make_node({ type = .type, value = "atomic_i64" })
  root.identifiers["bool"] = make_node({ type = .type, value = "bool" })
  root.identifiers["cint"] = make_node({ type = .type, value = "cint" })
  root.identifiers["cuint"] = make_node({ type = .type, value = "cuint" })
  root.identifiers["f32"] = make_node({ type = .type, value = "f32" })
  root.identifiers["f64"] = make_node({ type = .type, value = "f64" })
  root.identifiers["i8"] = make_node({ type = .type, value = "i8" })
  root.identifiers["i16"] = make_node({ type = .type, value = "i16" })
  root.identifiers["i32"] = make_node({ type = .type, value = "i32" })
  root.identifiers["i64"] = make_node({ type = .type, value = "i64" })
  root.identifiers["u8"] = make_node({ type = .type, value = "u8" })
  root.identifiers["u16"] = make_node({ type = .type, value = "u16" })
  root.identifiers["u32"] = make_node({ type = .type, value = "u32" })
  root.identifiers["u64"] = make_node({ type = .type, value = "u64" })

  allocator_type := make_node({ type = .type, value = "[procedure]" })
  append(&allocator_type.children, make_node({ type = .type, value = "[parameters]" }))

  string_type := make_node({ type = .type, value = "[slice]" })
  append(&string_type.children, root.identifiers["u8"])

  code_allocator_type := clone_node(allocator_type)
  append(&code_allocator_type.children[0].children, make_node({ type = .assignment_statement }))
  append(&code_allocator_type.children[0].children[0].children, make_node({ type = .identifier, value = "src", data_type = string_type }))
  append(&code_allocator_type.children, string_type)
  root.identifiers["code_allocator"] = code_allocator_type

  memory_allocator_type := clone_node(allocator_type)
  append(&memory_allocator_type.children[0].children, make_node({ type = .assignment_statement }))
  append(&memory_allocator_type.children[0].children[0].children, make_node({ type = .identifier, value = "size", data_type = root.identifiers["i64"] }))
  append(&memory_allocator_type.children, make_node({ type = .reference }))
  append(&memory_allocator_type.children[1].children, root.identifiers["u8"])
  root.identifiers["memory_allocator"] = memory_allocator_type

  nil_allocator_type := clone_node(allocator_type)
  root.identifiers["nil_allocator"] = nil_allocator_type

  static_allocator_type := clone_node(allocator_type)
  append(&static_allocator_type.children, root.identifiers["i64"])
  root.identifiers["static_allocator"] = static_allocator_type

  root.identifiers["code"] = make_node({ type = .identifier, value = "code", data_type = code_allocator_type })
  root.identifiers["extern"] = make_node({ type = .identifier, value = "extern", data_type = nil_allocator_type })
  root.identifiers["none"] = make_node({ type = .identifier, value = "none", data_type = nil_allocator_type })
  root.identifiers["stack"] = make_node({ type = .identifier, value = "stack", data_type = static_allocator_type })
  root.identifiers["static"] = make_node({ type = .identifier, value = "static", data_type = static_allocator_type })
}

get_module :: proc(root: ^scope, path: []string) -> ^scope
{
  return get_scope(root, path[:2])
}

get_scope :: proc(root: ^scope, path: []string) -> ^scope
{
  the_scope := root
  for path_element in path
  {
    if !(path_element in the_scope.children)
    {
      return nil
    }

    the_scope = the_scope.children[path_element]
  }

  return the_scope
}

resolve_identifier :: proc(root: ^scope, path: []string, identifier: ^node) -> (^node, []string)
{
  if is_member(identifier) && identifier.children[0].data_type != nil && identifier.children[0].data_type.value == "[module]"
  {
    child_node := identifier.children[0]

    module := get_module(root, path)
    if !(child_node.value in module.references)
    {
      return nil, {}
    }

    imported_module_path := module.references[child_node.value][:]
    imported_module := get_module(root, imported_module_path)
    if !(identifier.value in imported_module.identifiers)
    {
      return nil, {}
    }

    resolved_identifier := imported_module.identifiers[identifier.value]
    if resolved_identifier.directive == "#private"
    {
      return nil, {}
    }

    return resolved_identifier, imported_module_path
  }

  for path_length := len(path); path_length >= 0; path_length -= 1
  {
    scope_path := path[:path_length]
    scope := get_scope(root, scope_path)

    if identifier.value in scope.identifiers
    {
      resolved_identifier := scope.identifiers[identifier.value]
      if path_length == len(scope_path) || visible_in_nested_scope(root, resolved_identifier)
      {
        return resolved_identifier, path
      }
    }
  }

  return nil, {}
}

visible_in_nested_scope :: proc(root: ^scope, identifier: ^node) -> bool
{
  if is_type(identifier) || identifier.data_type.value == "[module]" do return true

  // Should only be core allocators that do not have an allocator themselves...
  if identifier.allocator == nil do return false

  memory_allocator := identifier.allocator.data_type.value == "[procedure]" && identifier.allocator.data_type.children[1].type == .reference
  return !memory_allocator && identifier.allocator != root.identifiers["stack"]
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

is_link_statement :: proc(statement: ^node) -> bool
{
  return statement.type == .call && statement.children[0].value == "link"
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
  for final_identifier.children[0].type == .dereference || final_identifier.children[0].type == .index || final_identifier.children[0].type == .reference
  {
    final_identifier = final_identifier.children[0]
  }

  return final_identifier.children[0].type == .identifier || final_identifier.children[0].type == .type
}

is_type :: proc(type: ^node) -> bool
{
  if type.type == .type
  {
    return true
  }

  if type.type == .reference
  {
    return is_type(type.children[0])
  }

  return false
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
