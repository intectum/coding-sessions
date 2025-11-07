package type_checking

import "../ast"

type_check_statement :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  #partial switch node.type
  {
  case .if_statement:
    return type_check_if(ctx, node)
  case .basic_for_statement:
    return type_check_basic_for(ctx, node)
  case .ranged_for_statement:
    return type_check_ranged_for(ctx, node)
  case .switch_:
    return type_check_switch(ctx, node)
  case .continue_statement:
    return type_check_continue(ctx, node)
  case .break_statement:
    return type_check_break(ctx, node)
  case .return_statement:
    return type_check_return(ctx, node)
  case .scope_statement:
    return type_check_scope(ctx, node)
  case .assignment_statement:
    return type_check_assignment(ctx, node)
  case:
    return type_check_rhs_expression(ctx, node, nil)
  }
}
