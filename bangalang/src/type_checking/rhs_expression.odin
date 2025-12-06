package type_checking

import "core:slice"

import "../ast"
import "../src"

type_check_rhs_expression :: proc(ctx: ^type_checking_context, node: ^ast.node, expected_type_node: ^ast.node) -> bool
{
  if node.type == .compound_literal
  {
    if expected_type_node == nil
    {
      src.print_position_message(node.src_position, "Could not determine type of compound literal")
      return false
    }

    node.data_type = expected_type_node
  }

  type_check_rhs_expression_1(ctx, node) or_return

  type_node := node.data_type
  coerced_type_node, coerce_ok := coerce_type(type_node, expected_type_node)
  if !coerce_ok
  {
    src.print_position_message(node.src_position, "Types '%s' and '%s' are not compatible", type_name(type_node), type_name(expected_type_node))
    return false
  }

  if coerced_type_node != nil
  {
    upgrade_types(ctx, node, coerced_type_node)
  }

  return true
}

type_check_rhs_expression_1 :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  _, binary_operator := slice.linear_search(ast.binary_operators, node.type)
  if !binary_operator
  {
    type_node := node.data_type
    directive := node.directive != "" ? node.directive : (type_node != nil ? type_node.directive : "")
    convert_soa_index(ctx, node)
    type_check_primary(ctx, node) or_return

    if directive != ""
    {
      node.data_type.directive = directive
    }

    return true
  }

  lhs_node := node.children[0]
  type_check_rhs_expression_1(ctx, lhs_node) or_return

  rhs_node := node.children[1]
  type_check_rhs_expression_1(ctx, rhs_node) or_return

  lhs_type_node := lhs_node.data_type
  rhs_type_node := rhs_node.data_type
  coerced_type_node, coerce_ok := coerce_type(lhs_type_node, rhs_type_node)
  if !coerce_ok
  {
    src.print_position_message(node.src_position, "Types '%s' and '%s' are not compatible", type_name(lhs_type_node), type_name(rhs_type_node))
    return false
  }

  _, comparison_operator := slice.linear_search(ast.comparison_operators, node.type)
  if comparison_operator
  {
    node.data_type = ctx.root.identifiers["bool"]
    if coerced_type_node.value == "[any_float]"
    {
      upgrade_types(ctx, lhs_node, ctx.root.identifiers["f64"])
      upgrade_types(ctx, rhs_node, ctx.root.identifiers["f64"])
    }
    else if coerced_type_node.value == "[any_number]"
    {
      upgrade_types(ctx, lhs_node, ctx.root.identifiers["i64"])
      upgrade_types(ctx, rhs_node, ctx.root.identifiers["i64"])
    }
    else
    {
      upgrade_types(ctx, lhs_node, coerced_type_node)
      upgrade_types(ctx, rhs_node, coerced_type_node)
    }
  }
  else
  {
    node.data_type = coerced_type_node
    upgrade_types(ctx, lhs_node, coerced_type_node)
    upgrade_types(ctx, rhs_node, coerced_type_node)
  }

  if node.type != .equal && node.type != .not_equal
  {
    _, numerical_type := slice.linear_search(numerical_types, coerced_type_node.value)
    if coerced_type_node.value == "bool"
    {
      if node.type != .and && node.type != .or
      {
        src.print_position_message(node.src_position, "Binary operator '%s' is not valid for type '%s'", node.type, type_name(node.data_type))
        return false
      }
    }
    else if !numerical_type || node.type == .and || node.type == .or
    {
      src.print_position_message(node.src_position, "Binary operator '%s' is not valid for type '%s'", node.type, type_name(node.data_type))
      return false
    }

    _, float_type := slice.linear_search(float_types, coerced_type_node.value)
    if float_type && (node.type == .bitwise_and || node.type == .bitwise_or || node.type == .modulo)
    {
      src.print_position_message(node.src_position, "Binary operator '%s' is not valid for type '%s'", node.type, type_name(node.data_type))
      return false
    }

    _, atomic_integer_type := slice.linear_search(atomic_integer_types, coerced_type_node.value)
    if atomic_integer_type && !comparison_operator
    {
      src.print_position_message(node.src_position, "Binary operator '%s' is not valid for type '%s'", node.type, type_name(node.data_type))
      return false
    }
  }

  return true
}
