package type_checking

import "core:slice"
import "core:strconv"
import "core:strings"

import "../ast"
import "../src"

type_check_compound_literal :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  type_node := node.data_type

  _, valid_type := slice.linear_search([]string { "[array]", "[slice]", "[struct]" }, type_node.value)
  if !valid_type
  {
    src.print_position_message(node.src_position, "Cannot use compound literal for type '%s'", type_name(type_node))
    return false
  }

  if len(node.children) == 0
  {
    return true
  }

  if node.children[0].type != .assignment_statement
  {
    switch type_node.value
    {
    case "[array]":
      length := strconv.atoi(type_node.children[1].value)
      if len(node.children) != length
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

    for &child_node in node.children
    {
      child_type_node := type_node.children[0]
      type_check_rhs_expression(ctx, child_node, child_type_node)
    }
  }
  else
  {
    switch type_node.value
    {
    case "[slice]":
      if len(node.children) != 2
      {
        src.print_position_message(node.src_position, "Compound literal for type '%s' must contain 2 elements", type_name(type_node))
        return false
      }
    case "[struct]":
      // Do nothing
    case:
      src.print_position_message(node.src_position, "Cannot use compound literal with assignments for type '%s'", type_name(type_node))
      return false
    }

    found_member_names: [dynamic]string
    for &child_node in node.children
    {
      child_lhs_node := child_node.children[0]

      _, duplicate_member_found := slice.linear_search(found_member_names[:], child_lhs_node.value)
      if duplicate_member_found
      {
        src.print_position_message(node.src_position, "'%s' is a duplicate member", child_lhs_node.value)
        return false
      }

      append(&found_member_names, child_lhs_node.value)

      found_member := false
      switch type_node.value
      {
      case "[slice]":
        switch child_lhs_node.value
        {
        case "raw":
          raw_type_node := ast.make_node({ type = .reference })
          append(&raw_type_node.children, type_node.children[0])
          child_lhs_node.data_type = raw_type_node
          found_member = true
        case "length":
          child_lhs_node.data_type = ctx.program.identifiers["u64"]
          found_member = true
        }
      case "[struct]":
        for member_node in type_node.children
        {
          if member_node.value == child_lhs_node.value
          {
            child_lhs_node.data_type = member_node.data_type
            found_member = true
            break
          }
        }
      case:
        assert(false, "Unsupported compound-literal")
      }

      if !found_member
      {
        src.print_position_message(node.src_position, "'%s' is not a member", child_lhs_node.value)
        return false
      }

      child_rhs_node := child_node.children[2]
      type_check_rhs_expression(ctx, child_rhs_node, child_lhs_node.data_type) or_return
    }
  }

  return true
}
