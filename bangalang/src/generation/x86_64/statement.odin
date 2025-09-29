package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_statement :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  #partial switch node.type
  {
  case .if_:
    generate_if(ctx, node)
  case .for_:
    generate_for(ctx, node)
  case .return_:
    generate_return(ctx, node)
  case .scope:
    generate_scope(ctx, node)
  case .assignment:
    generate_assignment(ctx, node)
  case:
    fmt.sbprintln(&ctx.output, "  ; expression")
    generate_expression(ctx, node)
  }
}
