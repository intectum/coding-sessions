package x86_64

import "core:fmt"
import "core:slice"
import "core:strconv"
import "core:strings"

import "../../ast"
import "../../type_checking"
import ".."

generate_compound_literal :: proc(ctx: ^generation.gen_context, node: ^ast.node, register_num: int) -> location
{
  type_node := node.data_type
  allocate_stack(ctx, to_byte_size(type_node))

  if len(node.children) > 0 && node.children[0].type != .assignment_statement
  {
    switch type_node.value
    {
    case "[array]":
      element_type_node := type_node.children[0]
      element_size := to_byte_size(element_type_node)

      element_location := memory("rsp", 0)
      for child_node in node.children
      {
        expression_location := generate_expression(ctx, child_node, register_num)
        copy(ctx, expression_location, element_location, element_type_node)
        element_location.offset += element_size
      }
    case "[slice]":
      element_type_node := type_node.children[0]
      element_size := to_byte_size(element_type_node)

      path_name := program.get_path_name(ctx.path)
      slice_array_index := ctx.next_index
      ctx.next_index += 1
      static_var_name := fmt.aprintf("%s.$array_%i", path_name, slice_array_index)

      static_var_type_node := ast.make_node({ type = .type, value = "[array]" })
      append(&static_var_type_node.children, element_type_node)
      append(&static_var_type_node.children, ast.make_node({ type = .number_literal, value = fmt.aprintf("%i", len(node.children)) }))

      static_var_node := ast.make_node({ type = .assignment_statement })
      append(&static_var_node.children, ast.make_node({ type = .identifier, value = static_var_name, data_type = static_var_type_node }))
      ctx.root.static_vars[static_var_name] = static_var_node

      element_location := memory(static_var_name, 0)
      for child_node in node.children
      {
        expression_location := generate_expression(ctx, child_node, register_num)
        copy(ctx, expression_location, element_location, element_type_node)
        element_location.offset += element_size
      }

      slice_address_location := memory("rsp", 0)
      slice_length_location := memory("rsp", address_size)
      copy(ctx, immediate(static_var_name), slice_address_location, reference_type_node)
      copy(ctx, immediate(len(node.children)), slice_length_location, length_type_node)
    case:
      assert(false, "Failed to generate compound literal")
    }
  }
  else
  {
    switch type_node.value
    {
    case "[slice]":
      member_names: []string = { "raw", "length" }
      for member_name in member_names
      {
        member_type_node := reference_type_node
        member_location := memory("rsp", 0)
        if member_name == "length"
        {
          member_type_node = ast.make_node({ type = .type, value = "i64" })
          member_location.offset += address_size
        }

        found_assignment := false
        for child_node in node.children
        {
          child_lhs_node := child_node.children[0]
          child_rhs_node := child_node.children[2]

          if child_lhs_node.value == member_name
          {
            expression_location := generate_expression(ctx, child_rhs_node, register_num)
            copy(ctx, expression_location, member_location, member_type_node)
            found_assignment = true
            break
          }
        }

        if !found_assignment
        {
          nilify(ctx, member_location, member_type_node)
        }
      }
    case "[struct]":
      member_location := memory("rsp", 0)
      for member_node in type_node.children
      {
        member_type_node := member_node.data_type

        found_assignment := false
        for child_node in node.children
        {
          child_lhs_node := child_node.children[0]
          child_rhs_node := child_node.children[2]

          if child_lhs_node.value == member_node.value
          {
            expression_location := generate_expression(ctx, child_rhs_node, register_num)
            copy(ctx, expression_location, member_location, member_type_node)
            found_assignment = true
            break
          }
        }

        if !found_assignment
        {
          nilify(ctx, member_location, member_type_node)
        }

        member_location.offset += to_byte_size(member_node.data_type)
      }
    case:
      assert(false, "Failed to generate compound literal")
    }
  }

  return copy_stack_address(ctx, 0, register_num)
}
