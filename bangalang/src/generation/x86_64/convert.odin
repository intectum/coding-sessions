package x86_64

import "core:fmt"
import "core:slice"

import "../../ast"
import "../../type_checking"
import ".."

convert :: proc(ctx: ^generation.gen_context, src: location, register_num: int, src_type_node: ^ast.node, dest_type_node: ^ast.node) -> location
{
  if dest_type_node.value == src_type_node.value
  {
    return src
  }

  dest := register(register_num, dest_type_node)

  _, src_float_type := slice.linear_search(type_checking.float_types, src_type_node.value)
  _, src_atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, src_type_node.value)
  _, src_signed_integer_type := slice.linear_search(type_checking.signed_integer_types, src_type_node.value)
  _, src_unsigned_integer_type := slice.linear_search(type_checking.unsigned_integer_types, src_type_node.value)

  _, dest_float_type := slice.linear_search(type_checking.float_types, dest_type_node.value)
  _, dest_atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, dest_type_node.value)
  _, dest_signed_integer_type := slice.linear_search(type_checking.signed_integer_types, dest_type_node.value)
  _, dest_unsigned_integer_type := slice.linear_search(type_checking.unsigned_integer_types, dest_type_node.value)

  src_size := to_byte_size(src_type_node)
  dest_size := to_byte_size(dest_type_node)

  if src_atomic_integer_type || src_signed_integer_type || src_unsigned_integer_type
  {
    if dest_atomic_integer_type || dest_signed_integer_type || dest_unsigned_integer_type
    {
        zero_extension := src_unsigned_integer_type || dest_unsigned_integer_type
        if dest_size > src_size && zero_extension && src_size < 4 && dest_size < 8
        {
          src_non_immediate := copy_to_non_immediate(ctx, src, register_num + 1, src_type_node)
          fmt.sbprintfln(&ctx.output, "  movzx %s, %s %s ; convert", to_operand(dest), to_operation_size(src_size), to_operand(src_non_immediate))
        }
        else if dest_size > src_size && !zero_extension && src_size < 4
        {
          src_non_immediate := copy_to_non_immediate(ctx, src, register_num + 1, src_type_node)
          fmt.sbprintfln(&ctx.output, "  movsx %s, %s %s ; convert", to_operand(dest), to_operation_size(src_size), to_operand(src_non_immediate))
        }
        else if dest_size > src_size && src.type == .memory
        {
          copy(ctx, src, register(register_num, src_type_node), src_type_node, "convert")
        }
        else if src.type == .register
        {
          dest = register(src.register_number, dest_type_node)
        }
        else
        {
          dest = src
        }
    }
    else if dest_float_type
    {
      fmt.sbprintfln(&ctx.output, "  cvtsi2s%s %s, %s ; convert", to_precision_size(dest_size), to_operand(dest), to_operand(src))
    }
    else
    {
      assert(false, "Failed to generate conversion")
    }
  }
  else if src_float_type
  {
    if dest_atomic_integer_type || dest_signed_integer_type || dest_unsigned_integer_type
    {
      large_dest := register(register_num, ctx.program.identifiers["u64"])
      fmt.sbprintfln(&ctx.output, "  cvtts%s2si %s, %s ; convert", to_precision_size(src_size), to_operand(large_dest), to_operand(src))
    }
    else if dest_float_type
    {
      fmt.sbprintfln(&ctx.output, "  cvts%s2s%s %s, %s ; convert", to_precision_size(src_size), to_precision_size(dest_size), to_operand(dest), to_operand(src))
    }
    else
    {
      assert(false, "Failed to generate conversion")
    }
  }
  else
  {
    assert(false, "Failed to generate conversion")
  }

  return dest
}
