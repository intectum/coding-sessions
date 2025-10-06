package type_checking

import "core:slice"
import "core:strconv"
import "core:strings"

import "../ast"
import "../src"

type_check_primary :: proc(node: ^ast.node, ctx: ^type_checking_context, allow_undefined: bool) -> bool
{
  if node.type != .compound_literal && len(node.children) > 0 && !ast.is_type(&node.children[0])
  {
    type_check_primary(&node.children[0], ctx, allow_undefined) or_return
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

    type_node := ast.node { type = .reference }
    append(&type_node.children, ast.get_type(&node.children[0])^)
    append(&node.children, type_node)
  case .negate:
    child_type_node := ast.get_type(&node.children[0])
    _, numerical_type := slice.linear_search(numerical_types, child_type_node.value)
    if !numerical_type
    {
      src.print_position_message(node.src_position, "Cannot negate type '%s'", type_name(child_type_node))
      return false
    }

    append(&node.children, child_type_node^)
  case .not:
    child_type_node := ast.get_type(&node.children[0])
    if child_type_node.value != "bool"
    {
      src.print_position_message(node.src_position, "Cannot invert type '%s'", type_name(child_type_node))
      return false
    }

    append(&node.children, child_type_node^)
  case .dereference:
    child_type_node := ast.get_type(&node.children[0])
    if child_type_node.type != .reference
    {
      src.print_position_message(node.src_position, "Cannot dereference type '%s'", type_name(child_type_node))
      return false
    }

    append(&node.children, child_type_node.children[0])
  case .index:
    identifier := node.children[0].value // TODO *eyebrow raise*

    auto_dereference(&node.children[0])

    child_type_node := ast.get_type(&node.children[0])
    if child_type_node.value != "[array]" && child_type_node.value != "[slice]"
    {
      src.print_position_message(node.src_position, "Cannot index type '%s'", type_name(child_type_node))
      return false
    }

    append(&node.children, child_type_node.children[0])

    any_int_type_node := ast.node { type = .type, value = "[any_int]" }

    type_check_rhs_expression(&node.children[1], ctx, &any_int_type_node) or_return
    upgrade_types(&node.children[1], &ctx.program.identifiers["i64"], ctx)

    if len(node.children) == 4
    {
      type_check_rhs_expression(&node.children[2], ctx, &any_int_type_node) or_return
      upgrade_types(&node.children[2], &ctx.program.identifiers["i64"], ctx)

      type_node := ast.node { type = .type, value = "[slice]" }
      append(&type_node.children, ast.get_type(node)^)
      ast.get_type(node)^ = type_node
    }

    if child_type_node.value == "[array]"
    {
      length := strconv.atoi(child_type_node.children[1].value)

      if child_type_node.directive != "#boundless" && node.children[1].type == .number && strconv.atoi(node.children[1].value) >= length
      {
        src.print_position_message(node.src_position, "Index %i out of bounds of '%s'", strconv.atoi(node.children[1].value), identifier)
        return false
      }
    }
  case .call:
    type_check_call(node, ctx) or_return
  case .identifier:
    type_check_identifier(node, ctx, allow_undefined) or_return
  case .string_:
    append(&node.children, ast.node { type = .type, value = "[any_string]" })
  case .number:
    type := strings.contains(node.value, ".") ? "[any_float]" : "[any_number]"
    append(&node.children, ast.node { type = .type, value = type })
  case .boolean:
    append(&node.children, ctx.program.identifiers["bool"])
  case .compound_literal:
    type_node := ast.get_type(node)

    for child_node in node.children[:len(node.children) - 1]
    {
      if child_node.type != .assignment
      {
        src.print_position_message(node.src_position, "Compound literal can only contain assignments")
        return false
      }

      child_lhs_node := &child_node.children[0]
      if child_lhs_node.type != .identifier || len(child_lhs_node.children) > 0
      {
        src.print_position_message(node.src_position, "Compound literal can only contain assignments to members")
        return false
      }

      found_member := false
      if type_node.value == "[struct]"
      {
        for &member_node in type_node.children
        {
          if member_node.value == child_lhs_node.value
          {
            append(&child_lhs_node.children, ast.get_type(&member_node)^)
            found_member = true
            break
          }
        }
      }
      else if type_node.value == "[slice]"
      {
        switch child_lhs_node.value
        {
        case "raw":
          raw_type_node := ast.node { type = .reference }
          append(&raw_type_node.children, type_node.children[0])
          append(&child_lhs_node.children, raw_type_node)
          found_member = true
        case "length":
          append(&child_lhs_node.children, ctx.program.identifiers["i64"])
          found_member = true
        }
      }
      else
      {
        src.print_position_message(node.src_position, "Cannot use compound literal with type '%s'", type_node.value)
        return false
      }

      if !found_member
      {
        src.print_position_message(node.src_position, "'%s' is not a member", child_lhs_node.value)
        return false
      }

      if len(child_node.children) == 1
      {
        src.print_position_message(node.src_position, "Compound literal can only contain assignments with right-hand-side expressions")
        return false
      }

      child_rhs_node := &child_node.children[2]
      type_check_rhs_expression(child_rhs_node, ctx, ast.get_type(child_lhs_node)) or_return
    }
  case .nil_:
    append(&node.children, ast.node { type = .type, value = "nil" })
  case .type:
    assert(false, "Failed to type check primary")
  case:
    type_check_rhs_expression_1(node, ctx) or_return
  }

  return true
}
