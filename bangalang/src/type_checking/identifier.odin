package type_checking

import "core:fmt"
import "core:slice"
import "core:strconv"

import "../ast"
import "../program"
import "../src"

type_check_identifier :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if ast.is_member(node)
  {
    child_node := node.children[0]
    if ast.is_type(child_node)
    {
      found_member := false

      if child_node.value == "[enum]"
      {
        for member_node in child_node.children
        {
          if member_node.value == node.value
          {
            node.data_type = child_node
            found_member = true
            break
          }
        }
      }

      if !found_member
      {
        switch node.value
        {
        case "max", "min":
          _, integer := slice.linear_search(numerical_types, child_node.value)
          if !integer
          {
            src.print_position_message(node.src_position, "'%s' is not a member of type '%s'", node.value, type_name(child_node))
            return false
          }

          _, integer2 := slice.linear_search(integer_types, child_node.value)

          node.data_type = child_node
        case "name": node.data_type = ctx.program.identifiers["string"]
        case "size": node.data_type = ctx.program.identifiers["i64"]
        case:
          src.print_position_message(node.src_position, "'%s' is not a member of type '%s'", node.value, type_name(child_node))
          return false
        }
      }
    }
    else
    {
      auto_dereference(child_node)

      child_type_node := child_node.data_type
      switch child_type_node.value
      {
      case "[array]", "[slice]":
        if node.value == "raw"
        {
          raw_type_node := ast.make_node({ type = .reference })
          append(&raw_type_node.children, child_type_node.children[0])
          node.data_type = raw_type_node
        }
        else if node.value == "length"
        {
          node.data_type = ctx.program.identifiers["i64"]
        }
        else
        {
          type_check_swizzle_member(node) or_return
        }
      case "[module]":
        identifier_node, identifier_path := get_identifier_node(ctx, node)
        if identifier_node == nil
        {
          src.print_position_message(node.src_position, "'%s' has not been declared", node.value)
          return false
        }

        if is_static_procedure(ctx.program, identifier_node) && !has_placeholders(identifier_node)
        {
          reference(ctx, identifier_path, node.value)
        }

        node.data_type = identifier_node.data_type
        node.allocator = identifier_node.allocator
      case "[struct]":
        found_member := false
        for member_node in child_type_node.children
        {
          if member_node.value == node.value
          {
            node.data_type = member_node.data_type
            found_member = true
            break
          }
        }

        if !found_member
        {
          src.print_position_message(node.src_position, "'%s' is not a member of variable '%s' with type '%s'", node.value, child_node.value, type_name(child_type_node))
          return false
        }
      case:
        assert(false, "Failed to type check identifier")
      }
    }
  }
  else
  {
    identifier_node, identifier_path := get_identifier_node(ctx, node)
    if identifier_node == nil
    {
      src.print_position_message(node.src_position, "'%s' has not been declared", node.value)
      return false
    }

    if is_static_procedure(ctx.program, identifier_node) && !has_placeholders(identifier_node)
    {
      reference(ctx, identifier_path, node.value)
    }

    node.data_type = identifier_node.data_type
    node.allocator = identifier_node.allocator
  }

  return true
}

type_check_swizzle_member :: proc(node: ^ast.node) -> bool
{
  child_node := node.children[0]
  child_type_node := child_node.data_type
  element_type_node := child_type_node.children[0]

  if element_type_node.value != "f32"
  {
    src.print_position_message(node.src_position, "'%s' is not a member of variable '%s' with type '%s'", node.value, child_node.value, type_name(child_type_node))
    return false
  }

  length := -1
  if child_type_node.value == "[array]"
  {
    length = strconv.atoi(child_type_node.children[1].value)
  }

  for char in node.value
  {
    index := get_swizzle_index(char)
    if index == -1
    {
      src.print_position_message(node.src_position, "'%s' is not a member of type '%s'", node.value, type_name(child_type_node))
      return false
    }

    if length != -1 && index >= length
    {
      src.print_position_message(node.src_position, "Index %i out of bounds (swizzling with value '%c')", index, char)
      return false
    }
  }

  if len(node.value) > 4
  {
    src.print_position_message(node.src_position, "Cannot swizzle with more than 4 values")
    return false
  }

  if len(node.value) == 1
  {
    node.data_type = element_type_node
  }
  else
  {
    type_node := ast.make_node({ type = .type, value = "[array]" })
    append(&type_node.children, element_type_node)
    append(&type_node.children, ast.make_node({ type = .number_literal, value = fmt.aprintf("%i", len(node.value)) }))
    node.data_type = type_node
  }

  return true
}
