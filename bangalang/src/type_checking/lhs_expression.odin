package type_checking

import "core:slice"

import "../ast"
import "../src"

type_check_lhs_expression :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if node.data_type != nil
  {
    identifier_node, _ := resolve_identifier(ctx, node, true)
    if identifier_node != nil
    {
      src.print_position_message(node.src_position, "'%s' has already been declared", node.value)
      return false
    }

    if node.data_type.value == "[array]" && node.data_type.directive == "#soa"
    {
      child_type_node := node.data_type.children[0]
      if child_type_node.value == "[struct]"
      {
        length_expression_node := node.data_type.children[1]

        new_type_node := ast.make_node({ type = .type, value = "[struct]", directive = "#soa" })

        for member_node in child_type_node.children
        {
          new_member_node := ast.make_node({ type = .identifier, value = member_node.value })

          new_member_type_node := ast.make_node({ type = .type, value = "[array]" })
          append(&new_member_type_node.children, ast.make_node({ type = .type, value = member_node.data_type.value }))
          append(&new_member_type_node.children, length_expression_node)
          new_member_node.data_type = new_member_type_node

          append(&new_type_node.children, new_member_node)
        }

        node.data_type = new_type_node
      }
    }

    type_check_allocator(ctx, node) or_return
  }
  else
  {
    convert_soa_index(ctx, node)
    type_check_primary(ctx, node) or_return
  }

  return true
}

core_allocator_names: []string = { "code", "extern", "none", "stack", "static" }
type_check_allocator :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if node.allocator == nil
  {
    node.allocator = ctx.root.identifiers[node.data_type.value == "[procedure]" ? "code" : "stack"]
    return true
  }

  if node.allocator.type == .identifier && !ast.is_member(node.allocator)
  {
    _, core_allocator := slice.linear_search(core_allocator_names, node.allocator.value)
    if core_allocator
    {
      node.allocator = ctx.root.identifiers[node.allocator.value]
      return true
    }
  }

  type_check_rhs_expression(ctx, node.allocator, nil) or_return

  _, code_allocator := coerce_type(node.allocator.data_type, ctx.root.identifiers["code_allocator"])
  _, memory_allocator := coerce_type(node.allocator.data_type, ctx.root.identifiers["memory_allocator"])
  if !code_allocator && !memory_allocator
  {
    src.print_position_message(node.src_position, "Cannot apply allocator with type '%s'", type_name(node.allocator.data_type))
    return false
  }

  return true
}
