package type_checking

import "core:slice"

import "../ast"

type_check_for :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  for_ctx := copy_type_checking_context(ctx)
  for_ctx.within_for = true

  child_index := 0
  child_node := &node.children[child_index]
  child_index += 1

  _, statement := slice.linear_search(ast.statements, child_node.type)
  if statement
  {
    type_check_statement(child_node, &for_ctx) or_return

    child_node = &node.children[child_index]
    child_index += 1
  }

  type_check_rhs_expression(child_node, &for_ctx, &for_ctx.program.identifiers["bool"]) or_return

  child_node = &node.children[child_index]
  child_index += 1

  if len(node.children) > child_index
  {
    type_check_statement(child_node, &for_ctx) or_return

    child_node = &node.children[child_index]
    child_index += 1
  }

  type_check_statement(child_node, &for_ctx) or_return

  return true
}
