package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_scope :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  scope_ctx := generation.copy_context(ctx)

  fmt.sbprintln(&scope_ctx.output, "; scope start")

  generate_statements(&scope_ctx, node.children[:])

  fmt.sbprintln(&scope_ctx.output, "; scope end")

  deallocate_stack(&scope_ctx, scope_ctx.stack_size - ctx.stack_size)
  ctx.next_index = scope_ctx.next_index
  ctx.output = scope_ctx.output
}
