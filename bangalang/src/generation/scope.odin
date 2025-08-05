package generation

import "core:fmt"
import "core:os"

import "../ast"

generate_scope :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context, include_end_label := false)
{
  fmt.fprintln(file, "; scope start")

  scope_ctx := copy_gen_context(ctx, true)

  for &child_node in node.children
  {
    generate_statement(file, &child_node, &scope_ctx)
  }

  if include_end_label
  {
    fmt.fprintln(file, ".end:")
  }

  close_gen_context(file, ctx, &scope_ctx, "scope", true)

  fmt.fprintln(file, "; scope end")
}
