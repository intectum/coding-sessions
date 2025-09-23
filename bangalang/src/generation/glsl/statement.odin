package glsl

import "core:fmt"

import "../../ast"
import ".."

generate_statement :: proc(ctx: ^generation.gen_context, node: ^ast.node, include_semi_colon: bool)
{
  #partial switch node.type
  {
  case .if_:
    assert(false, "if not supported")
    //generate_if(ctx, node)
  case .for_:
    generate_for(ctx, node)
  case .return_:
    assert(false, "return not supported")
    //generate_return(ctx, node)
  case .scope:
    generate_scope(ctx, node)
  case .assignment:
    generate_assignment(ctx, node)
  case:
    generate_expression(ctx, node)
  }

  #partial switch node.type
  {
  case .if_, .for_, .scope:
  case:
    if include_semi_colon
    {
      fmt.sbprint(&ctx.output, ";")
    }
  }
}
