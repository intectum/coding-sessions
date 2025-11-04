package glsl

import "core:fmt"

import "../../ast"
import ".."

generate_statement :: proc(ctx: ^generation.gen_context, node: ^ast.node, include_semi_colon: bool)
{
  #partial switch node.type
  {
  case .if_statement:
    assert(false, "if not supported")
    //generate_if(ctx, node)
  case .basic_for_statement:
    generate_basic_for(ctx, node)
  case .switch_:
    assert(false, "switch not supported")
    //generate_switch(ctx, node)
  case .return_statement:
    assert(false, "return not supported")
    //generate_return(ctx, node)
  case .scope_statement:
    generate_scope(ctx, node)
  case .assignment_statement:
    generate_assignment(ctx, node)
  case:
    generate_expression(ctx, node)
  }

  #partial switch node.type
  {
  case .if_statement, .basic_for_statement, .scope_statement:
  case:
    if include_semi_colon
    {
      fmt.sbprint(&ctx.output, ";")
    }
  }
}
