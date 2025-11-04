package x86_64

import "core:fmt"
import "core:slice"
import "core:strconv"

import "../../ast"
import "../../type_checking"
import ".."

copy_stack_address :: proc(ctx: ^generation.gen_context, offset: int, register_num: int) -> location
{
  dest := register(register_num, &reference_type_node)
  copy(ctx, register("sp", &reference_type_node), dest, &reference_type_node, "copy stack address")
  return memory(to_operand(dest), offset)
}

copy_to_non_immediate :: proc(ctx: ^generation.gen_context, src: location, number: int, type_node: ^ast.node, comment: string = "copy to non-immediate") -> location
{
  if src.type != .immediate do return src

  return copy_to_register(ctx, src, number, type_node, comment)
}

copy_to_register :: proc(ctx: ^generation.gen_context, src: location, number: int, type_node: ^ast.node, comment: string = "copy to register") -> location
{
  if src.type == .register do return src

  register_dest := register(number, type_node)
  copy(ctx, src, register_dest, type_node, comment)
  return register_dest
}

copy :: proc(ctx: ^generation.gen_context, src: location, dest: location, type_node: ^ast.node, comment: string = "copy")
{
  assert(dest.type != .immediate, "Cannot copy to immediate")

  if dest == src do return

  _, float_type := slice.linear_search(type_checking.float_types, type_node.value)
  size := to_byte_size(type_node)

  if src.type == .register || dest.type == .register
  {
    if float_type
    {
      fmt.sbprintfln(&ctx.output, "  movs%s %s, %s ; %s", to_precision_size(size), to_operand(dest), to_operand(src), comment)
    }
    else
    {
      fmt.sbprintfln(&ctx.output, "  mov %s, %s ; %s", to_operand(dest), to_operand(src), comment)
    }
  }
  else if src.type == .immediate
  {
    assert(!float_type, "Cannot copy float from immediate")

    fmt.sbprintfln(&ctx.output, "  mov %s %s, %s ; %s", to_operation_size(size), to_operand(dest), to_operand(src), comment)
  }
  else
  {
    fmt.sbprintfln(&ctx.output, "  lea rsi, %s ; %s: src", to_operand(src), comment);
    fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; %s: dest", to_operand(dest), comment);
    fmt.sbprintfln(&ctx.output, "  mov rcx, %i ; %s: count", size, comment);
    fmt.sbprintfln(&ctx.output, "  rep movsb ; %s", comment);
  }
}

copy4 :: proc(ctx: ^generation.gen_context, src: location, dest: location, type_node: ^ast.node, comment: string = "")
{
  assert(src.type == .register, "Cannot copy4 from non-register")
  assert(dest.type == .memory, "Cannot copy4 to non-memory")

  element_type_node := &type_node.children[0]
  element_size := to_byte_size(element_type_node)
  precision := to_precision_size(element_size)

  length := strconv.atoi(type_node.children[1].value)

  if length == 4
  {
    fmt.sbprintfln(&ctx.output, "  movup%s %s, %s ; copy", precision, to_operand(dest), to_operand(src))
  }
  else
  {
    out := dest
    shift_left_shuffle_code := to_shuffle_code("yzwx")

    for index in 0..<length
    {
      fmt.sbprintfln(&ctx.output, "  movs%s %s, %s ; copy", precision, to_operand(out), to_operand(src))
      if index < length - 1
      {
        fmt.sbprintfln(&ctx.output, "  shufp%s %s, %s, %s ; shift left", precision, to_operand(src), to_operand(src), shift_left_shuffle_code)
      }

      out.offset += element_size
    }
  }
}
