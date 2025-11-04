package type_checking

import "../ast"

type_check_switch :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  child_index := 0
  expression_node := &node.children[child_index]
  child_index += 1

  type_check_rhs_expression(expression_node, ctx, nil) or_return
  expression_type_node := ast.get_type(expression_node)

  for child_index < len(node.children)
  {
    case_node := &node.children[child_index]
    child_index += 1

    case_expression_node := &case_node.children[0]
    if case_expression_node.type != .default
    {
      type_check_rhs_expression(case_expression_node, ctx, expression_type_node) or_return
    }

    case_statement_node := &case_node.children[1]
    type_check_scope(case_statement_node, ctx) or_return
  }

  return true
}
