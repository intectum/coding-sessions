package type_checking

import "../ast"
import "../program"

type_check_return :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if len(node.children) > 0
  {
    // TODO does not work for main procedure...
    qualified_name := program.get_qualified_name(ctx.path[:])
    procedure_node := ctx.program.procedures[qualified_name].statements[0].children[0]
    procedure_type_node := procedure_node.data_type

    expression_node := node.children[0]
    type_check_rhs_expression(ctx, expression_node, procedure_type_node.children[1]) or_return
  }

  return true
}
