package type_checking

import "core:slice"
import "core:strconv"
import "core:strings"

import "../ast"
import "../src"

type_check_primary :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if ast.is_type(node) do return type_check_type(ctx, node)

  if node.type != .compound_literal && len(node.children) > 0
  {
    type_check_primary(ctx, node.children[0]) or_return
  }

  #partial switch node.type
  {
  case .reference:
    _, literal := slice.linear_search(ast.literals, node.children[0].type)
    if literal
    {
      src.print_position_message(node.src_position, "Cannot reference '%s' literal", node.children[0].type)
      return false
    }

    type_node := ast.make_node({ type = .reference })
    append(&type_node.children, node.children[0].data_type)
    node.data_type = type_node
  case .negate:
    child_type_node := node.children[0].data_type
    _, numerical_type := slice.linear_search(numerical_types, child_type_node.value)
    _, unsigned_integer_type := slice.linear_search(unsigned_integer_types, child_type_node.value)
    if !numerical_type || unsigned_integer_type
    {
      src.print_position_message(node.src_position, "Cannot negate type '%s'", type_name(child_type_node))
      return false
    }

    node.data_type = child_type_node
  case .not:
    child_type_node := node.children[0].data_type
    if child_type_node.value != "bool"
    {
      src.print_position_message(node.src_position, "Cannot invert type '%s'", type_name(child_type_node))
      return false
    }

    node.data_type = child_type_node
  case .dereference:
    child_type_node := node.children[0].data_type
    if child_type_node.type != .reference
    {
      src.print_position_message(node.src_position, "Cannot dereference type '%s'", type_name(child_type_node))
      return false
    }

    node.data_type = child_type_node.children[0]
  case .subscript:
    auto_dereference(node.children[0])

    child_type_node := node.children[0].data_type
    if child_type_node.type != .subscript
    {
      src.print_position_message(node.src_position, "Cannot index type '%s'", type_name(child_type_node))
      return false
    }

    any_int_type_node := ast.make_node({ type = .identifier, value = "[any_int]" })

    start_expression_node := node.children[1]
    end_expression_node: ^ast.node = nil
    if node.children[1].type == .range
    {
      start_expression_node = node.children[1].children[0]
      end_expression_node = node.children[1].children[1]
    }

    type_check_rhs_expression(ctx, start_expression_node, any_int_type_node) or_return
    upgrade_types(ctx, start_expression_node, ctx.program.identifiers["u64"]) or_return

    if node.children[1].type != .range
    {
      node.data_type = child_type_node.children[0]
    }
    else
    {
      type_check_rhs_expression(ctx, end_expression_node, any_int_type_node) or_return
      upgrade_types(ctx, end_expression_node, ctx.program.identifiers["u64"]) or_return

      type_node := ast.make_node({ type = .subscript })
      append(&type_node.children, child_type_node.children[0])
      range_node := ast.make_node({ type = .range })
      append(&range_node.children, ast.make_node({ type = .nil_literal }))
      append(&range_node.children, ast.make_node({ type = .nil_literal }))
      append(&type_node.children, range_node)
      node.data_type = type_node
    }

    if ast.is_array(child_type_node)
    {
      length := strconv.atoi(child_type_node.children[1].value)

      if child_type_node.directive != "#danger_boundless" && start_expression_node.type == .number_literal && strconv.atoi(start_expression_node.value) >= length
      {
        src.print_position_message(node.src_position, "Index %i out of bounds", strconv.atoi(start_expression_node.value))
        return false
      }
    }
  case .call:
    type_check_call(ctx, node) or_return
  case .identifier:
    type_check_identifier(ctx, node) or_return
  case .char_literal:
    node.data_type = ctx.program.identifiers["char"]
  case .string_literal:
    node.data_type = ast.make_node({ type = .identifier, value = "[any_string]" })
  case .number_literal:
    type := strings.contains(node.value, ".") ? "[any_float]" : "[any_number]"
    node.data_type = ast.make_node({ type = .identifier, value = type })
  case .boolean_literal:
    node.data_type = ctx.program.identifiers["bool"]
  case .compound_literal:
    type_check_compound_literal(ctx, node) or_return
  case .nil_literal:
    node.data_type = ast.make_node({ type = .identifier, value = "[none]" })
  case .enum_type:
    for member_node, index in node.children[:len(node.children) - 1]
    {
      for other_member_node in node.children[index + 1:]
      {
        if other_member_node.value == member_node.value
        {
          src.print_position_message(other_member_node.src_position, "Duplicate member '%s' found in type '%s'", other_member_node.value, type_name(node))
          return false
        }
      }
    }
  case .procedure_type:
    // Do nothing
  case .struct_type:
    for member_node, index in node.children[:len(node.children) - 1]
    {
      for other_member_node in node.children[index + 1:]
      {
        if other_member_node.value == member_node.value
        {
          src.print_position_message(other_member_node.src_position, "Duplicate member '%s' found in type '%s'", other_member_node.value, type_name(node))
          return false
        }
      }
    }
  case:
    type_check_rhs_expression_1(ctx, node) or_return
  }

  if node.directive == "#danger_untyped"
  {
    node.data_type = ast.make_node({ type = .identifier, value= "[none]" })
  }

  return true
}
