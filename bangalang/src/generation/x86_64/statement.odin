package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_statement :: proc(ctx: ^generation.gen_context, node: ^ast.node, include_end_label := false)
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
    generate_scope(ctx, node, include_end_label)
  case .assignment:
    generate_assignment(ctx, node)
  case:
    fmt.sbprintln(&ctx.output, "  ; expression")
    generate_expression(ctx, node)
  }

  if node.type != .scope && include_end_label
  {
    fmt.sbprintln(&ctx.output, ".end:")
  }
}
