package x86_64

import "core:c"
import "core:fmt"
import "core:math"

import "../../ast"
import "../../program"
import "../../type_checking"
import ".."

generate_identifier :: proc(ctx: ^generation.gen_context, node: ^ast.node, register_num: int, child_location: location, contains_allocations: bool) -> location
{
  type_node := node.data_type
  if type_node.value == "[module]"
  {
    return {}
  }

  if ast.is_member(node)
  {
    child_node := node.children[0]
    if ast.is_type(child_node)
    {
      if child_node.value == "[enum]"
      {
        for member_node, index in child_node.children
        {
          if member_node.value == node.value
          {
            return immediate(index)
          }
        }
      }

      switch node.value
      {
      case "max":
        switch child_node.value
        {
        case "f32": return memory(get_literal_name(&ctx.program.f32_literals, "f32_", fmt.aprintf("%f", math.max(f32))), 0)
        case "f64": return memory(get_literal_name(&ctx.program.f64_literals, "f64_", fmt.aprintf("%f", math.max(f64))), 0)
        case "atomic_i8", "i8": return immediate(int(math.max(i8)))
        case "atomic_i16", "i16": return immediate(int(math.max(i16)))
        case "atomic_i32", "i32": return immediate(int(math.max(i32)))
        case "atomic_i64", "i64": return immediate(int(math.max(i64)))
        case "cint": return immediate(int(math.max(c.int)))
        case "cuint": return immediate(int(math.max(c.uint)))
        case "u8": return immediate(int(math.max(u8)))
        case "u16": return immediate(int(math.max(u16)))
        case "u32": return immediate(int(math.max(u32)))
        case "u64": return immediate(fmt.aprintf("%i", math.max(u64)))
        case: assert(false, "Failed to generate identifier")
        }
      case "min":
        switch child_node.value
        {
        case "f32": return memory(get_literal_name(&ctx.program.f32_literals, "f32_", fmt.aprintf("%f", math.min(f32))), 0)
        case "f64": return memory(get_literal_name(&ctx.program.f64_literals, "f64_", fmt.aprintf("%f", math.min(f64))), 0)
        case "atomic_i8", "i8": return immediate(int(math.min(i8)))
        case "atomic_i16", "i16": return immediate(int(math.min(i16)))
        case "atomic_i32", "i32": return immediate(int(math.min(i32)))
        case "atomic_i64", "i64": return immediate(int(math.min(i64)))
        case "cint": return immediate(int(math.min(c.int)))
        case "cuint": return immediate(int(math.min(c.uint)))
        case "u8": return immediate(int(math.min(u8)))
        case "u16": return immediate(int(math.min(u16)))
        case "u32": return immediate(int(math.min(u32)))
        case "u64": return immediate(int(math.min(u64)))
        case: assert(false, "Failed to generate identifier")
        }
      case "name":
        // TODO as static var?
        return memory(get_literal_name(&ctx.program.string_literals, "string_", fmt.aprintf("\"%s\"", type_checking.type_name(child_node))), 0)
      case "size": return immediate(to_byte_size(child_node))
      case: assert(false, "Failed to generate identifier")
      }
    }

    child_type_node := child_node.data_type
    switch child_type_node.value
    {
    case "[array]", "[slice]":
      if node.value == "raw"
      {
        return get_raw_location(ctx, child_type_node, child_location, register_num)
      }
      else if node.value == "length"
      {
        return get_length_location(child_type_node, child_location)
      }
      else
      {
        element_type_node := child_type_node.children[0]
        element_size := to_byte_size(element_type_node)

        address_location := get_raw_location(ctx, child_type_node, child_location, register_num)
        address_location = copy_to_register(ctx, address_location, register_num, reference_type_node)
        memory_location := memory(to_operand(address_location), 0)

        max_index := 0
        for char in node.value
        {
          index := type_checking.get_swizzle_index(char)
          if index > max_index do max_index = index
        }

        if child_type_node.value == "[slice]"
        {
          length_location := get_length_location(child_type_node, child_location)
          fmt.sbprintfln(&ctx.output, "  cmp qword %s, %s ; compare", to_operand(length_location), to_operand(immediate(max_index)))
          fmt.sbprintln(&ctx.output, "  jle panic_out_of_bounds ; panic!")
        }

        if len(node.value) == 1
        {
          index := type_checking.get_swizzle_index(rune(node.value[0]))

          memory_location.offset += index * element_size
          return memory_location
        }

        precision := to_precision_size(element_size)

        register_location := register(register_num, element_type_node)

        fmt.sbprintfln(&ctx.output, "  movup%s %s, %s ; copy", precision, to_operand(register_location), to_operand(memory_location))
        fmt.sbprintfln(&ctx.output, "  shufp%s %s, %s, %s ; swizzle", precision, to_operand(register_location), to_operand(register_location), to_shuffle_code(node.value))

        allocate_stack(ctx, to_byte_size(type_node))
        copy4(ctx, register_location, memory("rsp", 0), type_node)

        return copy_stack_address(ctx, 0, register_num)
      }
    case "[module]":
      // Do nothing
    case "[struct]":
      location := child_location

      for member_node in child_type_node.children
      {
        if member_node.value == node.value
        {
          break
        }

        location.offset += to_byte_size(member_node.data_type)
      }

      return location
    case:
      assert(false, "Failed to generate identifier")
    }
  }

  _, memory_allocator := type_checking.coerce_type(node.allocator.data_type, ctx.program.identifiers["memory_allocator"])
  if !memory_allocator && node.allocator != ctx.program.identifiers["stack"]
  {
    name := node.value

    // TODO add #namespaced=false
    if node.allocator != ctx.program.identifiers["extern"]
    {
      // TODO hacky
      tc_ctx: type_checking.type_checking_context = { program = ctx.program, path = ctx.path }
      _, identifier_path := type_checking.get_identifier_node(&tc_ctx, node)

      path: [dynamic]string
      append(&path, ..identifier_path)
      append(&path, node.value)
      defer delete(path)

      name = program.get_qualified_name(path[:])
    }

    if type_node.value == "[procedure]" || type_node.type == .reference
    {
      return immediate(name)
    }

    return memory(name, 0)
  }

  variable_position := ctx.stack_size - ctx.stack_variable_offsets[node.value]
  if contains_allocations
  {
    return copy_stack_address(ctx, variable_position, register_num)
  }
  else
  {
    return memory("rsp", variable_position)
  }
}
