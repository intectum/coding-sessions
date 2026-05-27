package type_checking

import "../ast"
import "../loading"

type_check_return :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if len(node.children) > 0
  {
    return_type := ctx.root.identifiers["u8"]
    if len(ctx.scope.path) > 2
    {
      procedure := ctx.scope.statements[0].children[0]
      return_type = procedure.data_type.children[1]
    }

    expression_node := node.children[0]
    type_check_rhs_expression(ctx, expression_node, return_type) or_return
  }

  return true
}
