package type_checking

import "../ast"

type_check_if :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  child_index := 0
  expression_node := node.children[child_index]
  child_index += 1

  type_check_rhs_expression(ctx, expression_node, ctx.program.identifiers["bool"]) or_return

  statement_node := node.children[child_index]
  child_index += 1

  type_check_scope(ctx, statement_node) or_return

  for child_index + 1 < len(node.children)
  {
    type_check_rhs_expression(ctx, node.children[child_index], ctx.program.identifiers["bool"]) or_return
    child_index += 1

    type_check_scope(ctx, node.children[child_index]) or_return
    child_index += 1
  }

  if child_index < len(node.children)
  {
    type_check_scope(ctx, node.children[child_index]) or_return
    child_index += 1
  }

  return true
}
