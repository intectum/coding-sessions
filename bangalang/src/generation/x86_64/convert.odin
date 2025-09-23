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

  dest_location := register(register_num, dest_type_node)

  _, src_float_type := slice.linear_search(type_checking.float_types, src_type_node.value)
  _, src_atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, src_type_node.value)
  _, src_signed_integer_type := slice.linear_search(type_checking.signed_integer_types, src_type_node.value)

  _, dest_float_type := slice.linear_search(type_checking.float_types, dest_type_node.value)
  _, dest_atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, dest_type_node.value)
  _, dest_signed_integer_type := slice.linear_search(type_checking.signed_integer_types, dest_type_node.value)

  src_size := to_byte_size(src_type_node)
  dest_size := to_byte_size(dest_type_node)

  if src_atomic_integer_type || src_signed_integer_type
  {
    if dest_atomic_integer_type || dest_signed_integer_type
    {
      if dest_size > src_size
      {
        fmt.sbprintfln(&ctx.output, "  movsx %s, %s %s ; convert", to_operand(dest_location), to_operation_size(src_size), to_operand(src))
      }
      else if src.type != .register
      {
        dest_location = src
      }
    }
    else if dest_float_type
    {
      fmt.sbprintfln(&ctx.output, "  cvtsi2s%s %s, %s ; convert", to_precision_size(dest_size), to_operand(dest_location), to_operand(src))
    }
  }
  else if src_float_type
  {
    if dest_atomic_integer_type || dest_signed_integer_type
    {
      fmt.sbprintfln(&ctx.output, "  cvtts%s2si %s, %s ; convert", to_precision_size(src_size), to_operand(dest_location), to_operand(src))
    }
    else if dest_float_type
    {
      fmt.sbprintfln(&ctx.output, "  cvts%s2s%s %s, %s ; convert", to_precision_size(src_size), to_precision_size(dest_size), to_operand(dest_location), to_operand(src))
    }
  }

  return dest_location
}
