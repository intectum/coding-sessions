package type_checking

import "core:slice"

import "../ast"

type_check_basic_for :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  for_ctx := copy_context(ctx)
  for_ctx.within_for = true

  child_index := 0
  child_node := node.children[child_index]
  child_index += 1

  if child_node.type == .assignment_statement
  {
    type_check_assignment(child_node, &for_ctx) or_return

    child_node = node.children[child_index]
    child_index += 1
  }

  type_check_rhs_expression(child_node, &for_ctx, for_ctx.program.identifiers["bool"]) or_return

  child_node = node.children[child_index]
  child_index += 1

  if len(node.children) > child_index
  {
    type_check_assignment(child_node, &for_ctx) or_return

    child_node = node.children[child_index]
    child_index += 1
  }

  type_check_scope(child_node, &for_ctx) or_return

  ctx.next_index = for_ctx.next_index

  return true
}
