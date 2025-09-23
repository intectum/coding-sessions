package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_scope :: proc(ctx: ^generation.gen_context, node: ^ast.node, include_end_label := false)
{
  fmt.sbprintln(&ctx.output, "; scope start")

  initial_stack_size := ctx.stack_size

  for &child_node in node.children
  {
    generate_statement(ctx, &child_node)
  }

  if include_end_label
  {
    fmt.sbprintln(&ctx.output, ".end:")
  }

  deallocate_stack(ctx, ctx.stack_size - initial_stack_size)

  fmt.sbprintln(&ctx.output, "; scope end")
}
