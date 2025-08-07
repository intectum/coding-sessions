package generation

import "core:fmt"
import "core:os"

import "../ast"

allocate_stack :: proc(file: os.Handle, size: int, ctx: ^gen_context)
{
  if size > 0
  {
    fmt.fprintfln(file, "  sub rsp, %i ; allocate (stack)", size)
    ctx.stack_size += size
  }
}

deallocate_stack :: proc(file: os.Handle, size: int, ctx: ^gen_context)
{
  if size > 0
  {
    fmt.fprintfln(file, "  add rsp, %i ; deallocate (stack)", size)
    ctx.stack_size -= size
  }
}
