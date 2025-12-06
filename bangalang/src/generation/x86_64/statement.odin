package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_statement :: proc(ctx: ^generation.gen_context, output: ^output, node: ^ast.node)
{
  #partial switch node.type
  {
  case .if_statement:
    generate_if(ctx, output, node)
  case .basic_for_statement:
    generate_basic_for(ctx, output, node)
  case .switch_:
    generate_switch(ctx, output, node)
  case .continue_statement:
    generate_continue(ctx, output, node)
  case .break_statement:
    generate_break(ctx, output, node)
  case .return_statement:
    generate_return(ctx, output, node)
  case .scope_statement:
    generate_scope(ctx, output, node)
  case .assignment_statement:
    generate_assignment(ctx, output, node)
  case:
    fmt.sbprintln(&ctx.output, "  ; expression")
    generate_expression(ctx, output, node)
  }
}
