package type_checking

import "../ast"

type_check_statement :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  #partial switch node.type
  {
  case .if_statement:
    return type_check_if(node, ctx)
  case .basic_for_statement:
    return type_check_basic_for(node, ctx)
  case .ranged_for_statement:
    return type_check_ranged_for(node, ctx)
  case .switch_:
    return type_check_switch(node, ctx)
  case .continue_statement:
    return type_check_continue(node, ctx)
  case .break_statement:
    return type_check_break(node, ctx)
  case .return_statement:
    return type_check_return(node, ctx)
  case .scope_statement:
    return type_check_scope(node, ctx)
  case .assignment_statement:
    return type_check_assignment(node, ctx)
  case:
    return type_check_rhs_expression(node, ctx, nil)
  }
}
