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

  found_all_returns := true

  type_check_scope(ctx, statement_node) or_return

  if found_all_returns do found_all_returns = ctx.found_return
  ctx.found_return = false

  for child_index + 1 < len(node.children)
  {
    type_check_rhs_expression(ctx, node.children[child_index], ctx.program.identifiers["bool"]) or_return
    child_index += 1

    type_check_scope(ctx, node.children[child_index]) or_return
    child_index += 1

    if found_all_returns do found_all_returns = ctx.found_return
    ctx.found_return = false
  }

  found_else := false
  if child_index < len(node.children)
  {
    type_check_scope(ctx, node.children[child_index]) or_return
    child_index += 1

    if found_all_returns do found_all_returns = ctx.found_return
    ctx.found_return = false
    found_else = true
  }

  ctx.found_return = found_all_returns && found_else

  return true
}
