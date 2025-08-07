package ast

import "core:slice"

import "../ast"
import "../tokens"

is_link_statement :: proc(statement: ^node) -> bool
{
  return statement.type == .call && statement.children[0].value == "link"
}

is_import_statement :: proc(statement: ^node) -> bool
{
  if statement.type == .assignment && len(statement.children) > 1
  {
    rhs_node := &statement.children[2]
    return rhs_node.type == .call && rhs_node.children[0].value == "import"
  }

  return false
}

is_type_alias_statement :: proc(statement: ^node) -> bool
{
  return statement.type == .assignment && len(statement.children) > 1 && is_type(&statement.children[2])
}

is_static_procedure_statement :: proc(statement: ^node) -> bool
{
  return statement.type == .assignment && !is_type(&statement.children[0]) && is_static_procedure(&statement.children[0])
}

is_static_assignment_statement :: proc(statement: ^node) -> bool
{
  return statement.type == .assignment && !is_type(&statement.children[0]) && get_allocator(&statement.children[0]) == "static"
}

is_static_procedure :: proc(identifier: ^node) -> bool
{
  type := get_type(identifier)
  if type == nil || type.value != "[procedure]"
  {
    return false
  }

  if is_member(identifier) && get_type(&identifier.children[0]).value != "[module]"
  {
    return false
  }

  return get_allocator(identifier) == "static"
}

is_member :: proc(identifier: ^node) -> bool
{
  if identifier.type != .identifier || len(identifier.children) == 0
  {
    return false
  }

  final_identifier := identifier
  for final_identifier.children[0].type == .dereference || final_identifier.children[0].type == .reference
  {
    final_identifier = &final_identifier.children[0]
  }

  return final_identifier.children[0].type == .identifier
}

get_allocator :: proc(identifier: ^node) -> string
{
  type := get_type(identifier)
  if type.allocator != ""
  {
    return type.allocator
  }

  if is_member(identifier) && get_type(&identifier.children[0]).value != "[module]"
  {
    return get_allocator(&identifier.children[0])
  }

  return type.value == "[procedure]" ? "static" : "stack"
}

is_type :: proc(type: ^node) -> bool
{
  if type.type == .type
  {
    return true
  }

  if type.type == .reference
  {
    return is_type(&type.children[0])
  }

  return false
}

get_type :: proc(identifier: ^node) -> ^node
{
  child_count := len(identifier.children)
  if child_count == 0
  {
    return nil
  }

  if is_type(&identifier.children[child_count - 1])
  {
    return &identifier.children[child_count - 1]
  }

  return nil
}

to_node_type :: proc(token_type: tokens.token_type) -> node_type
{
  #partial switch token_type
  {
  case .equals:
    return .assign
  case .equals_equals:
    return .equal
  case .exclamation_equals:
    return .not_equal
  case .opening_angle_bracket:
    return .less_than
  case .closing_angle_bracket:
    return .greater_than
  case .opening_angle_bracket_equals:
    return .less_than_or_equal
  case .closing_angle_bracket_equals:
    return .greater_than_or_equal
  case .plus:
    return .add
  case .plus_equals:
    return .add_assign
  case .minus:
    return .subtract
  case .minus_equals:
    return .subtract_assign
  case .asterisk:
    return .multiply
  case .asterisk_equals:
    return .multiply_assign
  case .backslash:
    return .divide
  case .backslash_equals:
    return .divide_assign
  case .percent:
    return .modulo
  case .percent_equals:
    return .modulo_assign
  case .ampersand_ampersand:
    return .and
  case .pipe_pipe:
    return .or
  }

  assert(false, "Unsupported node type")
  return .none
}
