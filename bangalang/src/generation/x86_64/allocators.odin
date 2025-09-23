package x86_64

import "core:fmt"

import "../../ast"
import ".."

allocate_stack :: proc(ctx: ^generation.gen_context, size: int)
{
  if size > 0
  {
    fmt.sbprintfln(&ctx.output, "  sub rsp, %i ; allocate (stack)", size)
    ctx.stack_size += size
  }
}

deallocate_stack :: proc(ctx: ^generation.gen_context, size: int)
{
  if size > 0
  {
    fmt.sbprintfln(&ctx.output, "  add rsp, %i ; deallocate (stack)", size)
    ctx.stack_size -= size
  }
}
