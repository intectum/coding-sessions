package generation

import "core:fmt"
import "core:os"

import "../ast"

generate_statement :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context, include_end_label := false)
{
  #partial switch node.type
  {
  case .if_:
    generate_if(file, node, ctx)
  case .for_:
    generate_for(file, node, ctx)
  case .return_:
    generate_return(file, node, ctx)
  case .scope:
    generate_scope(file, node, ctx, include_end_label)
  case .assignment:
    generate_assignment(file, node, ctx)
  case:
    fmt.fprintln(file, "  ; expression")
    generate_expression(file, node, ctx)
  }

  if node.type != .scope && include_end_label
  {
    fmt.fprintln(file, ".end:")
  }
}
