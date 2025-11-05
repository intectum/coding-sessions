package type_checking

import "core:slice"
import "core:strconv"
import "core:strings"

import "../ast"
import "../src"

type_check_primary :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  if node.type != .compound_literal && len(node.children) > 0 && !ast.is_type(node.children[0])
  {
    type_check_primary(node.children[0], ctx) or_return
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
    append(&type_node.children, ast.get_type(node.children[0]))
    append(&node.children, type_node)
  case .negate:
    child_type_node := ast.get_type(node.children[0])
    _, numerical_type := slice.linear_search(numerical_types, child_type_node.value)
    _, unsigned_integer_type := slice.linear_search(unsigned_integer_types, child_type_node.value)
    if !numerical_type || unsigned_integer_type
    {
      src.print_position_message(node.src_position, "Cannot negate type '%s'", type_name(child_type_node))
      return false
    }

    append(&node.children, child_type_node)
  case .not:
    child_type_node := ast.get_type(node.children[0])
    if child_type_node.value != "bool"
    {
      src.print_position_message(node.src_position, "Cannot invert type '%s'", type_name(child_type_node))
      return false
    }

    append(&node.children, child_type_node)
  case .dereference:
    child_type_node := ast.get_type(node.children[0])
    if child_type_node.type != .reference
    {
      src.print_position_message(node.src_position, "Cannot dereference type '%s'", type_name(child_type_node))
      return false
    }

    append(&node.children, child_type_node.children[0])
  case .index:
    auto_dereference(node.children[0])

    child_type_node := ast.get_type(node.children[0])
    if child_type_node.value != "[array]" && child_type_node.value != "[slice]"
    {
      src.print_position_message(node.src_position, "Cannot index type '%s'", type_name(child_type_node))
      return false
    }

    append(&node.children, ast.clone_node(child_type_node.children[0]))

    any_int_type_node := ast.make_node({ type = .type, value = "[any_int]" })

    type_check_rhs_expression(node.children[1], ctx, any_int_type_node) or_return
    upgrade_types(node.children[1], ctx.program.identifiers["i64"], ctx)

    if len(node.children) == 4
    {
      type_check_rhs_expression(node.children[2], ctx, any_int_type_node) or_return
      upgrade_types(node.children[2], ctx.program.identifiers["i64"], ctx)

      type_node := ast.node { type = .type, value = "[slice]" }
      append(&type_node.children, ast.clone_node(ast.get_type(node)))
      ast.get_type(node)^ = type_node
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
    type_check_call(node, ctx) or_return
  case .identifier:
    type_check_identifier(node, ctx) or_return
  case .char_literal:
    append(&node.children, ctx.program.identifiers["char"])
  case .string_literal:
    append(&node.children, ast.make_node({ type = .type, value = "[any_string]" }))
  case .number_literal:
    type := strings.contains(node.value, ".") ? "[any_float]" : "[any_number]"
    append(&node.children, ast.make_node({ type = .type, value = type }))
  case .boolean_literal:
    append(&node.children, ctx.program.identifiers["bool"])
  case .compound_literal:
    type_check_compound_literal(node, ctx) or_return
  case .nil_literal:
    append(&node.children, ast.make_node({ type = .type, value = "[none]" }))
  case .type:
    assert(false, "Failed to type check primary")
  case:
    type_check_rhs_expression_1(node, ctx) or_return
  }

  if node.directive == "#danger_untyped"
  {
    node.children[len(node.children) - 1] = ast.make_node({ type = .type, value= "[none]" })
  }

  return true
}
