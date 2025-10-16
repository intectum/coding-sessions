package x86_64

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:strings"

import "../../ast"
import "../../type_checking"
import ".."

generate_primary :: proc(ctx: ^generation.gen_context, node: ^ast.node, register_num: int, contains_allocations: bool) -> location
{
  child_location: location
  if node.type != .compound_literal && len(node.children) > 0 && !ast.is_type(&node.children[0])
  {
    child_location = generate_primary(ctx, &node.children[0], register_num, contains_allocations)
  }

  type_node := ast.get_type(node)

  #partial switch node.type
  {
  case .reference:
    location := register(register_num, type_node)
    fmt.sbprintfln(&ctx.output, "  lea %s, %s ; reference", to_operand(location), to_operand(child_location))
    return location
  case .negate:
    location := copy_to_register(ctx, child_location, register_num, type_node)

    _, float_type := slice.linear_search(type_checking.float_types, type_node.value)
    if float_type
    {
      sign_mask_name := strings.concatenate({ type_node.value, "_sign_mask" })
      sign_mask := copy_to_register(ctx, memory(sign_mask_name, 0), register_num + 1, type_node)
      fmt.sbprintfln(&ctx.output, "  xorp%s %s, %s ; negate", to_precision_size(to_byte_size(type_node)), to_operand(location), to_operand(sign_mask))
    }
    else
    {
      fmt.sbprintfln(&ctx.output, "  neg %s ; negate", to_operand(location))
    }

    return location
  case .not:
    location := copy_to_register(ctx, child_location, register_num, type_node)
    fmt.sbprintfln(&ctx.output, "  xor byte %s, 1 ; not", to_operand(location))
    return location
  case .dereference:
    location := copy_to_register(ctx, child_location, register_num, &unknown_reference_type_node, "dereference")
    return memory(to_operand(location), 0)
  case .index:
    child_type_node := ast.get_type(&node.children[0])

    child_length_location := get_length_location(child_type_node, child_location)

    start_expression_node := &node.children[1]
    start_expression_location := immediate(0)
    if start_expression_node.type != .nil_
    {
      start_expression_location = generate_expression(ctx, start_expression_node, register_num + 1)
    }

    start_expression_type_node := ast.get_type(start_expression_node)
    start_expression_location = copy_to_register(ctx, start_expression_location, register_num + 1, start_expression_type_node)
    start_expression_location = convert(ctx, start_expression_location, register_num + 1, start_expression_type_node, &index_type_node)

    if start_expression_node.type != .nil_ && type_node.directive != "#boundless"
    {
      fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare", to_operand(start_expression_location), to_operand(child_length_location))
      fmt.sbprintln(&ctx.output, "  jge panic_out_of_bounds ; panic!")
      fmt.sbprintfln(&ctx.output, "  cmp %s, 0 ; compare", to_operand(start_expression_location))
      fmt.sbprintln(&ctx.output, "  jl panic_out_of_bounds ; panic!")
    }

    if type_node.value != "[slice]" && node.children[1].type == .number
    {
      data_location := child_location
      if child_type_node.value == "[slice]"
      {
        data_location = copy_to_register(ctx, data_location, register_num, &unknown_reference_type_node, "dereference")
        data_location = memory(to_operand(data_location), 0)
      }

      data_location.offset += strconv.atoi(start_expression_node.value) * to_byte_size(type_node)
      return data_location
    }

    address_location := get_raw_location(ctx, child_type_node, child_location, register_num)
    address_location = copy_to_register(ctx, address_location, register_num, &unknown_reference_type_node)
    offset_location := register(register_num + 2, &unknown_reference_type_node)
    element_type_node := child_type_node.value == "[array]" || child_type_node.value == "[slice]" ? &child_type_node.children[0] : child_type_node

    fmt.sbprintfln(&ctx.output, "  mov %s, %s ; copy", to_operand(offset_location), to_operand(start_expression_location))
    fmt.sbprintfln(&ctx.output, "  imul %s, %s ; multiply by element size", to_operand(offset_location), to_operand(immediate(to_byte_size(element_type_node))))
    fmt.sbprintfln(&ctx.output, "  add %s, %s ; offset", to_operand(address_location), to_operand(offset_location))

    if type_node.value == "[slice]"
    {
      allocate_stack(ctx, to_byte_size(type_node))
      slice_address_location := memory("rsp", 0)
      slice_length_location := memory("rsp", address_size)

      copy(ctx, address_location, slice_address_location, &unknown_reference_type_node)

      end_expression_node := &node.children[2]
      end_expression_location := child_length_location
      if end_expression_node.type != .nil_
      {
        end_expression_location = generate_expression(ctx, end_expression_node, register_num + 2)
      }

      end_expression_type_node := ast.get_type(end_expression_node)
      end_expression_location = copy_to_register(ctx, end_expression_location, register_num + 2, end_expression_type_node)
      end_expression_location = convert(ctx, end_expression_location, register_num + 2, end_expression_type_node, &index_type_node)

      if end_expression_node.type != .nil_ && type_node.directive != "#boundless"
      {
        fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare", to_operand(end_expression_location), to_operand(child_length_location))
        fmt.sbprintln(&ctx.output, "  jg panic_out_of_bounds ; panic!")
        fmt.sbprintfln(&ctx.output, "  cmp %s, 0 ; compare", to_operand(end_expression_location))
        fmt.sbprintln(&ctx.output, "  jl panic_out_of_bounds ; panic!")
      }

      fmt.sbprintfln(&ctx.output, "  mov %s, %s ; copy", to_operand(slice_length_location), to_operand(end_expression_location))
      fmt.sbprintfln(&ctx.output, "  sub %s, %s ; subtract", to_operand(slice_length_location), to_operand(start_expression_location))
      fmt.sbprintfln(&ctx.output, "  cmp qword %s, 0 ; compare", to_operand(slice_length_location))
      fmt.sbprintln(&ctx.output, "  jl panic_negative_slice_length ; panic!")

      return copy_stack_address(ctx, 0, register_num)
    }
    else
    {
      return memory(to_operand(address_location), 0)
    }
  case .call:
    return generate_call(ctx, node, register_num, child_location, false)
  case .identifier:
    return generate_identifier(ctx, node, register_num, child_location, contains_allocations)
  case .string_:
    if type_node.value == "[slice]" && type_node.children[0].value == "u8"
    {
      return memory(get_literal_name(&ctx.program.string_literals, "string_", node.value), 0)
    }
    else if type_node.value == "cstring"
    {
      return immediate(get_literal_name(&ctx.program.cstring_literals, "cstring_", node.value))
    }

    assert(false, "Failed to generate primary")
    return {}
  case .number:
    if type_node.value == "f32"
    {
      return memory(get_literal_name(&ctx.program.f32_literals, "f32_", node.value), 0)
    }
    else if type_node.value == "f64"
    {
      return memory(get_literal_name(&ctx.program.f64_literals, "f64_", node.value), 0)
    }

    return immediate(node.value)
  case .boolean:
    return immediate(node.value == "true" ? 1 : 0)
  case .compound_literal:
    return generate_compound_literal(ctx, node, register_num)
  case .nil_:
    return immediate(0)
  case:
    return generate_expression_1(ctx, node, register_num, contains_allocations)
  }
}
