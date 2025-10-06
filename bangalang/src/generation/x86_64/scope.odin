package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_scope :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  fmt.sbprintln(&ctx.output, "; scope start")

  initial_stack_size := ctx.stack_size

  generate_statements(ctx, node.children[:])

  deallocate_stack(ctx, ctx.stack_size - initial_stack_size)

  fmt.sbprintln(&ctx.output, "; scope end")
}
