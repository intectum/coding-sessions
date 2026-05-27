package type_checking

import "../ast"

type_check_return :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if len(node.children) > 0
  {
    return_data_type := ctx.program.identifiers["u8"]
    if len(ctx.path) > 2
    {
      procedure_node := ast.get_scope(ctx.program, ctx.path[:]).statements[0].children[0]
      return_data_type = procedure_node.data_type.children[1]
    }

    expression_node := node.children[0]
    type_check_rhs_expression(ctx, expression_node, return_data_type) or_return
  }

  return true
}
