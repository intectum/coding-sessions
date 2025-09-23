package glsl

import "core:fmt"
import "core:slice"
import "core:strings"

import "../../ast"
import ".."

generate_program :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  fmt.sbprintln(&ctx.output, "#version 460 core")
  fmt.sbprintln(&ctx.output, "")
  fmt.sbprintln(&ctx.output, "void main()")
  generate_statement(ctx, &node.children[2], true)
}
