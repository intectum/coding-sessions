package type_checking

import "../ast"

type_check_if :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  child_index := 0
  expression_node := node.children[child_index]
  child_index += 1

  type_check_rhs_expression(expression_node, ctx, ctx.program.identifiers["bool"]) or_return

  statement_node := node.children[child_index]
  child_index += 1

  type_check_scope(statement_node, ctx) or_return

  for child_index + 1 < len(node.children)
  {
    type_check_rhs_expression(node.children[child_index], ctx, ctx.program.identifiers["bool"]) or_return
    child_index += 1

    type_check_scope(node.children[child_index], ctx) or_return
    child_index += 1
  }

  if child_index < len(node.children)
  {
    type_check_scope(node.children[child_index], ctx) or_return
    child_index += 1
  }

  return true
}
