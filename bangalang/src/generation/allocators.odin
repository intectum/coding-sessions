package generation

import "core:fmt"
import "core:os"

import "../ast"

allocate_heap :: proc(file: os.Handle, size: int, ctx: ^gen_context)
{
  if size > 0
  {
    allocate_stack(file, address_size, ctx)

    fmt.fprintln(file, "  mov rax, 9 ; allocate (heap): syscall_num")
    fmt.fprintln(file, "  mov rdi, 0 ; allocate (heap): address")
    fmt.fprintfln(file, "  mov rsi, %i ; allocate (heap): length", size)
    fmt.fprintln(file, "  mov rdx, 0x3 ; allocate (heap): prot") // PROT_READ | PROT_WRITE
    fmt.fprintln(file, "  mov r10, 0x22 ; allocate (heap): flags") // MAP_PRIVATE | MAP_ANONYMOUS
    fmt.fprintln(file, "  mov r8, -1 ; allocate (heap): file_descriptor")
    fmt.fprintln(file, "  mov r9, 0 ; allocate (heap): offset")
    fmt.fprintln(file, "  syscall ; allocate (heap)")
    fmt.fprintln(file, "  mov [rsp], rax ; allocate (heap): assign pointer")
  }
}

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
