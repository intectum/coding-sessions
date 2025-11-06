package type_checking

import "core:slice"
import "core:strings"

import "../ast"
import "../src"

type_check_procedure :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  lhs_node := node.children[0]
  lhs_type_node := lhs_node.data_type
  allocator := ast.get_allocator(lhs_node)

  if len(node.children) == 1 && (allocator == "glsl" || allocator == "static")
  {
    src.print_position_message(lhs_node.src_position, "Must provide a procedure body when using allocator '%s'", allocator)
    return false
  }

  found_default := false
  params_type_node := lhs_type_node.children[0]
  for param_node in params_type_node.children
  {
    if len(param_node.children) == 1 && found_default
    {
      src.print_position_message(lhs_node.src_position, "Procedure parameters with defaults cannot be followed by parameters without defaults")
      return false
    }

    if len(param_node.children) > 1
    {
      found_default = true
    }

    param_lhs_node := param_node.children[0]
    param_lhs_node.allocator = "stack"

    type_check_assignment(param_node, ctx) or_return
  }

  if len(node.children) > 1
  {
    operator_node := node.children[1]
    rhs_node := node.children[2]

    if allocator == "extern" || allocator == "none"
    {
      src.print_position_message(lhs_node.src_position, "Cannot provide a procedure body when using allocator '%s'", allocator)
      return false
    }

    type_check_statements(ctx, rhs_node.children[:]) or_return

    if operator_node.type != .assign
    {
      src.print_position_message(operator_node.src_position, "Assignment operator '%s' is not valid for declarations", operator_node.value)
      return false
    }
  }

  return true
}
