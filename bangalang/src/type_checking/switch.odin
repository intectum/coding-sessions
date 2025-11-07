package type_checking

import "../ast"

type_check_switch :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  child_index := 0
  expression_node := node.children[child_index]
  child_index += 1

  type_check_rhs_expression(ctx, expression_node, nil) or_return
  expression_type_node := expression_node.data_type

  for child_index < len(node.children)
  {
    case_node := node.children[child_index]
    child_index += 1

    case_expression_node := case_node.children[0]
    if case_expression_node.type != .default
    {
      type_check_rhs_expression(ctx, case_expression_node, expression_type_node) or_return
    }

    case_statement_node := case_node.children[1]
    type_check_scope(ctx, case_statement_node) or_return
  }

  return true
}
