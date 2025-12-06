package type_checking

import "core:slice"
import "core:strconv"
import "core:strings"

import "../ast"
import "../src"

type_check_primary :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if node.type != .compound_literal && node.type != .type && len(node.children) > 0
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
  case .index:
    auto_dereference(node.children[0])

    child_type_node := node.children[0].data_type
    if child_type_node.value != "[array]" && child_type_node.value != "[slice]"
    {
      src.print_position_message(node.src_position, "Cannot index type '%s'", type_name(child_type_node))
      return false
    }

    any_int_type_node := ast.make_node({ type = .type, value = "[any_int]" })

    type_check_rhs_expression(ctx, node.children[1], any_int_type_node) or_return
    upgrade_types(ctx, node.children[1], ctx.root.identifiers["i64"])

    if len(node.children) == 2
    {
      node.data_type = child_type_node.children[0]
    }
    else
    {
      type_check_rhs_expression(ctx, node.children[2], any_int_type_node) or_return
      upgrade_types(ctx, node.children[2], ctx.root.identifiers["i64"])

      type_node := ast.make_node({ type = .type, value = "[slice]" })
      append(&type_node.children, child_type_node.children[0])
      node.data_type = type_node
    }

    if child_type_node.value == "[array]"
    {
      length := strconv.atoi(child_type_node.children[1].value)

      if child_type_node.directive != "#danger_boundless" && node.children[1].type == .number_literal && strconv.atoi(node.children[1].value) >= length
      {
        src.print_position_message(node.src_position, "Index %i out of bounds", strconv.atoi(node.children[1].value))
        return false
      }
    }
  case .call:
    type_check_call(ctx, node) or_return
  case .identifier:
    type_check_identifier(ctx, node) or_return
  case .char_literal:
    node.data_type = ctx.root.identifiers["char"]
  case .string_literal:
    node.data_type = ast.make_node({ type = .type, value = "[any_string]" })
  case .number_literal:
    type := strings.contains(node.value, ".") ? "[any_float]" : "[any_number]"
    node.data_type = ast.make_node({ type = .type, value = type })
  case .boolean_literal:
    node.data_type = ctx.root.identifiers["bool"]
  case .compound_literal:
    type_check_compound_literal(ctx, node) or_return
  case .nil_literal:
    node.data_type = ast.make_node({ type = .type, value = "[none]" })
  case .type:
    if node.value == "[enum]"
    {
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
    }
  case:
    type_check_rhs_expression_1(ctx, node) or_return
  }

  if node.directive == "#danger_untyped"
  {
    node.data_type = ast.make_node({ type = .type, value= "[none]" })
  }

  return true
}
