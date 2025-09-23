package glsl

import "core:fmt"
import "core:slice"

import "../../ast"
import ".."

generate_expression :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  _, binary_operator := slice.linear_search(ast.binary_operators, node.type)
  if !binary_operator
  {
    generate_primary(ctx, node)
    return
  }

  lhs_node := &node.children[0]
  rhs_node := &node.children[1]

  generate_expression(ctx, lhs_node)
  fmt.sbprintf(&ctx.output, " %s ", node.value)
  generate_expression(ctx, rhs_node)
}
