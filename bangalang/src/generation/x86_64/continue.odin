package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_continue :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  fmt.sbprintln(&ctx.output, "  ; continue")
  fmt.sbprintfln(&ctx.output, "  jmp .for_%i_continue ; continue", ctx.for_index)
}
