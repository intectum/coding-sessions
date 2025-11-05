package type_checking

import "core:slice"
import "core:strconv"
import "core:strings"

import "../ast"
import "../src"

type_check_compound_literal :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  type_node := ast.get_type(node)

  children := node.children[:len(node.children) - 1]

  for &child_node in children
  {
    if child_node.type != .assignment_statement
    {
      switch type_node.value
      {
      case "[array]":
        length := strconv.atoi(type_node.children[1].value)
        if len(children) != length
        {
          src.print_position_message(node.src_position, "Compound literal for type '%s' must contain %i elements", type_name(type_node), length)
          return false
        }
      case "[slice]":
        // Do nothing
      case:
        src.print_position_message(node.src_position, "Cannot use compound literal with values for type '%s'", type_name(type_node))
        return false
      }

      child_type_node := type_node.children[0]
      type_check_rhs_expression(child_node, ctx, child_type_node)
    }
    else
    {
      child_lhs_node := child_node.children[0]

      found_member := false
      switch type_node.value
      {
      case "[slice]":
        switch child_lhs_node.value
        {
        case "raw":
          raw_type_node := ast.make_node({ type = .reference })
          append(&raw_type_node.children, type_node.children[0])
          append(&child_lhs_node.children, raw_type_node)
          found_member = true
        case "length":
          append(&child_lhs_node.children, ctx.program.identifiers["i64"])
          found_member = true
        }
      case "[struct]":
        for member_node in type_node.children
        {
          if member_node.value == child_lhs_node.value
          {
            append(&child_lhs_node.children, ast.get_type(member_node))
            found_member = true
            break
          }
        }
      case:
        src.print_position_message(node.src_position, "Cannot use compound literal with assignments for type '%s'", type_name(type_node))
        return false
      }

      if !found_member
      {
        src.print_position_message(node.src_position, "'%s' is not a member", child_lhs_node.value)
        return false
      }

      child_rhs_node := child_node.children[2]
      type_check_rhs_expression(child_rhs_node, ctx, ast.get_type(child_lhs_node)) or_return
    }
  }

  return true
}
