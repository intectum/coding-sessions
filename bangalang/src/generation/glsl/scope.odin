package glsl

import "core:fmt"

import "../../ast"
import ".."

generate_scope :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  fmt.sbprintln(&ctx.output, "{")

  for child_node in node.children
  {
    generate_statement(ctx, child_node, true)
    fmt.sbprintln(&ctx.output, "")
  }

  fmt.sbprintln(&ctx.output, "}")
}
