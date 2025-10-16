package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_statement :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  #partial switch node.type
  {
  case .if_statement:
    generate_if(ctx, node)
  case .for_statement:
    generate_for(ctx, node)
  case .switch_:
    generate_switch(ctx, node)
  case .continue_statement:
    generate_continue(ctx, node)
  case .break_statement:
    generate_break(ctx, node)
  case .return_statement:
    generate_return(ctx, node)
  case .scope_statement:
    generate_scope(ctx, node)
  case .assignment_statement:
    generate_assignment(ctx, node)
  case:
    fmt.sbprintln(&ctx.output, "  ; expression")
    generate_expression(ctx, node)
  }
}
