package glsl

import "core:fmt"

import "../../ast"
import ".."

generate_identifier :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  if ast.is_member(node)
  {
    fmt.sbprintf(&ctx.output, ".")
  }

  if ast.is_type(node)
  {
    fmt.sbprintf(&ctx.output, type_name(node))
  }
  else
  {
    fmt.sbprintf(&ctx.output, node.value)
  }
}
