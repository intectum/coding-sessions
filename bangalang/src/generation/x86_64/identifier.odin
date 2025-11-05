package x86_64

import "core:fmt"

import "../../ast"
import "../../program"
import "../../type_checking"
import ".."

generate_identifier :: proc(ctx: ^generation.gen_context, node: ^ast.node, register_num: int, child_location: location, contains_allocations: bool) -> location
{
  type_node := ast.get_type(node)
  if type_node.value == "[module]"
  {
    return {}
  }

  if ast.is_member(node)
  {
    child_type_node := ast.get_type(node.children[0])
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

        location.offset += to_byte_size(ast.get_type(member_node))
      }

      return location
    case:
      assert(false, "Failed to generate identifier")
    }
  }

  allocator := ast.get_allocator(node)
  if allocator == "extern" || allocator == "glsl" || allocator == "none" || allocator == "static" // TODO glsl is temp here
  {
    name := node.value

    if (allocator != "extern" && allocator != "none") || node.value == "glsl_kernels" // TODO hmmm
    {
      if ast.is_member(node) && ast.get_type(node.children[0]).value == "[module]"
      {
        module := ctx.program.modules[program.get_qualified_module_name(ctx.path)]
        imported_module_path := module.imports[node.children[0].value]

        imported_member_path: [dynamic]string
        append(&imported_member_path, ..imported_module_path[:])
        append(&imported_member_path, node.value)
        defer delete(imported_member_path)

        name = program.get_qualified_name(imported_member_path[:])
      }
      else
      {
        // TODO hacky
        tc_ctx: type_checking.type_checking_context = { program = ctx.program, path = ctx.path }
        _, identifier_path := type_checking.get_identifier_node(&tc_ctx, node.value)

        path: [dynamic]string
        append(&path, ..identifier_path)
        append(&path, node.value)
        defer delete(path)

        name = program.get_qualified_name(path[:])
      }
    }

    if type_node.value == "[procedure]" || type_node.value == "cstring"
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
