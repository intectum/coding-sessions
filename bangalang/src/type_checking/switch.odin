package type_checking

import "../ast"

type_check_switch :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  child_index := 0
  expression_node := node.children[child_index]
  child_index += 1

  type_check_rhs_expression(ctx, expression_node, nil) or_return
  expression_type_node := expression_node.data_type

  found_all_returns := true

  found_default := false
  for child_index < len(node.children)
  {
    case_node := node.children[child_index]
    child_index += 1

    case_expression_node := case_node.children[0]
    if case_expression_node.type == .default
    {
      found_default = true
    }
    else
    {
      type_check_rhs_expression(ctx, case_expression_node, expression_type_node) or_return
    }

    case_statement_node := case_node.children[1]
    type_check_scope(ctx, case_statement_node) or_return

    if found_all_returns do found_all_returns = ctx.found_return
    ctx.found_return = false
  }

  ctx.found_return = found_all_returns && found_default

  return true
}
