package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_break :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  fmt.sbprintln(&ctx.output, "  ; break")
  fmt.sbprintfln(&ctx.output, "  jmp .for_%i_end ; break", ctx.for_index)
}
