package type_checking

import "core:slice"
import "core:strings"

import "../ast"
import "../src"

type_check_procedure :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  lhs_node := node.children[0]
  lhs_type_node := lhs_node.data_type

  _, code_allocator := ast.coerce_type(lhs_node.allocator.data_type, ctx.program.identifiers["code_allocator"])
  if len(node.children) == 1 && code_allocator
  {
    src.print_position_message(lhs_node.src_position, "Must provide a procedure body when using a code allocator")
    return false
  }

  params_type_node := lhs_type_node.children[0]
  for param_node in params_type_node.children
  {
    param_lhs_node := param_node.children[0]
    ctx.scope.identifiers[param_lhs_node.value] = param_lhs_node
  }

  if len(node.children) > 1
  {
    operator_node := node.children[1]
    rhs_node := node.children[2]

    _, nil_allocator := ast.coerce_type(lhs_node.allocator.data_type, ctx.program.identifiers["nil_allocator"])
    if nil_allocator
    {
      src.print_position_message(lhs_node.src_position, "Cannot provide a procedure body when using a nil allocator")
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
