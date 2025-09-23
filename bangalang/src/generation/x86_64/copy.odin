package x86_64

import "core:fmt"
import "core:slice"

import "../../ast"
import "../../type_checking"
import ".."

copy_stack_address :: proc(ctx: ^generation.gen_context, offset: int, register_num: int) -> location
{
  dest := register(register_num, &unknown_reference_type_node)
  copy(ctx, register("sp", &unknown_reference_type_node), dest, &unknown_reference_type_node, "copy stack address")
  return memory(to_operand(dest), offset)
}

copy_to_non_immediate :: proc(ctx: ^generation.gen_context, src: location, number: int, type_node: ^ast.node, comment: string = "") -> location
{
  if src.type != .immediate
  {
    return src
  }

  final_comment := "copy to non-immediate"
  if comment != ""
  {
    final_comment = comment
  }

  register_dest := register(number, type_node)
  copy(ctx, src, register_dest, type_node, final_comment)
  return register_dest
}

copy_to_register :: proc(ctx: ^generation.gen_context, src: location, number: int, type_node: ^ast.node, comment: string = "") -> location
{
  if src.type == .register
  {
    return src
  }

  final_comment := "copy to register"
  if comment != ""
  {
    final_comment = comment
  }

  register_dest := register(number, type_node)
  copy(ctx, src, register_dest, type_node, final_comment)
  return register_dest
}

copy :: proc(ctx: ^generation.gen_context, src: location, dest: location, type_node: ^ast.node, comment: string = "")
{
  assert(dest.type != .immediate, "Cannot copy to immediate")

  final_comment := "copy"
  if comment != ""
  {
    final_comment = comment
  }

  if dest == src
  {
    return
  }

  _, float_type := slice.linear_search(type_checking.float_types, type_node.value)
  size := to_byte_size(type_node)

  if src.type == .register || dest.type == .register
  {
    if float_type
    {
      fmt.sbprintfln(&ctx.output, "  movs%s %s, %s ; %s", to_precision_size(size), to_operand(dest), to_operand(src), final_comment)
    }
    else
    {
      fmt.sbprintfln(&ctx.output, "  mov %s, %s ; %s", to_operand(dest), to_operand(src), final_comment)
    }
  }
  else if src.type == .immediate
  {
    assert(!float_type, "Cannot copy float from immediate")

    fmt.sbprintfln(&ctx.output, "  mov %s %s, %s ; %s", to_operation_size(size), to_operand(dest), to_operand(src), final_comment)
  }
  else
  {
    fmt.sbprintfln(&ctx.output, "  lea rsi, %s ; %s: src", to_operand(src), final_comment);
    fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; %s: dest", to_operand(dest), final_comment);
    fmt.sbprintfln(&ctx.output, "  mov rcx, %i ; %s: count", size, final_comment);
    fmt.sbprintfln(&ctx.output, "  rep movsb ; %s", final_comment);
  }
}
