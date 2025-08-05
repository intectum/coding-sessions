package generation

import "core:os"

import "../ast"

generate_identifier :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context, register_num: int, child_location: location, contains_allocations: bool) -> location
{
  if ast.is_static_procedure(node)
  {
    return immediate(node.value)
  }
  else if ast.get_allocator(node) == "static"
  {
    return memory(node.value, 0)
  }

  if ast.is_member(node)
  {
    child_type_node := ast.get_type(&node.children[0])
    switch child_type_node.value
    {
    case "[struct]":
      location := child_location

      for &member_node in child_type_node.children
      {
        if member_node.value == node.value
        {
          break
        }

        location.offset += to_byte_size(ast.get_type(&member_node))
      }

      return location
    case "[array]", "[slice]":
      if node.value == "raw"
      {
        return get_raw_location(file, child_type_node, child_location, register_num)
      }
      else if node.value == "length"
      {
        return get_length_location(child_type_node, child_location)
      }
    case:
      assert(false, "Failed to generate identifier")
    }
  }

  variable_position := ctx.stack_size - ctx.stack_variable_offsets[node.value]
  if contains_allocations
  {
    return copy_stack_address(file, variable_position, register_num)
  }
  else
  {
    return memory("rsp", variable_position)
  }
}
