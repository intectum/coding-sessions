package ast

import "core:slice"

import "../ast"
import "../tokens"

make_node :: proc(init: node = {}) -> ^node
{
  new_node := new(ast.node)
  new_node^ = init
  return new_node
}

clone_node :: proc(root: ^node) -> ^node
{
  clone := make_node(root^)

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

is_static_procedure_statement :: proc(statement: ^node) -> bool
{
  return statement.type == .assignment_statement && is_static_procedure(statement.children[0])
}

is_static_procedure :: proc(identifier: ^node) -> bool
{
  type := identifier.data_type
  if type == nil || type.value != "[procedure]"
  {
    return false
  }

  if is_member(identifier) && identifier.children[0].data_type.value != "[module]"
  {
    return false
  }

  allocator := get_allocator(identifier)
  return allocator == "extern" || allocator == "glsl" || allocator == "none" || allocator == "static" // TODO glsl is temp here
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

get_allocator :: proc(identifier: ^node) -> string
{
  if identifier.allocator != ""
  {
    return identifier.allocator
  }

  if is_member(identifier) && identifier.children[0].data_type.value != "[module]"
  {
    return get_allocator(identifier.children[0])
  }

  return identifier.data_type.value == "[procedure]" ? "static" : "stack"
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

to_node :: proc(token: tokens.token) -> ^ast.node
{
  return make_node({
    type = ast.to_node_type(token.type),
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
  case .plus:
    return .add
  case .plus_equals:
    return .add_assign
  }

  assert(false, "Unsupported node type")
  return .none
}
