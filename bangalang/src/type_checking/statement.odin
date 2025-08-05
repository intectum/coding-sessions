package type_checking

import "../ast"

type_check_statement :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  #partial switch node.type
  {
  case .if_:
    return type_check_if(node, ctx)
  case .for_:
    return type_check_for(node, ctx)
  case .return_:
    return type_check_return(node, ctx)
  case .scope:
    return type_check_scope(node, ctx)
  case .assignment:
    return type_check_assignment(node, ctx)
  case:
    return type_check_rhs_expression(node, ctx, nil)
  }
}
