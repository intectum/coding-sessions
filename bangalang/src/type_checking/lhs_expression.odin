package type_checking

import "core:fmt"
import "core:slice"

import "../ast"
import "../src"

type_check_lhs_expression :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if node.data_type != nil
  {
    declaration, _ := ast.get_declaration(ctx.program, ctx.scope, node)
    if declaration != nil && !ctx.within_procedure_type // TODO a better way of expressing this
    {
      src.print_position_message(node.src_position, "'%s' has already been declared", node.value)
      return false
    }

    if node.data_type.value != "[none]"
    {
      type_check_primary(ctx, node.data_type) or_return
    }

    if ast.is_array(node.data_type) && ast.get_modifier(node, "#soa") != nil
    {
      child_type_node := node.data_type.children[0]
      if child_type_node.type == .struct_type
      {
        length_expression_node := node.data_type.children[1]

        new_type_node := ast.make_node({ type = .struct_type })
        new_type_node.modifier = ast.make_node({ type = .identifier, value = "#soa" })

        for member_node in child_type_node.children
        {
          new_member_node := ast.make_node({ type = .identifier, value = member_node.value })

          new_member_type_node := ast.make_node({ type = .subscript })
          append(&new_member_type_node.children, ast.make_node({ type = .identifier, value = member_node.data_type.value }))
          append(&new_member_type_node.children, length_expression_node)
          new_member_node.data_type = new_member_type_node

          append(&new_type_node.children, new_member_node)
        }

        node.data_type = new_type_node
      }
    }

    type_check_allocator(ctx, node) or_return

    if node.modifier != nil
    {
      type_check_modifier(ctx, node.modifier) or_return
    }

    alignment := ast.get_modifier(node, "#align")
    if alignment != nil && node.allocator == ctx.program.identifiers["stack"]
    {
      src.print_position_message(node.src_position, "Cannot align a stack allocated value")
      return false
    }
  }
  else
  {
    type_check_primary(ctx, node) or_return
  }

  return true
}

core_allocator_names: []string = { "code", "extern", "none", "stack", "static" }
type_check_allocator :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  procedure_type := node.data_type.type == .kernel_type || node.data_type.type == .procedure_type

  if node.allocator == nil
  {
    node.allocator = ctx.program.identifiers[procedure_type ? "code" : (len(ctx.scope.path) == 2 ? "static" : "stack")]
    return true
  }

  if node.allocator.type == .identifier && !ast.is_member(node.allocator)
  {
    if !procedure_type && node.allocator.value == "code"
    {
      src.print_position_message(node.src_position, "Cannot apply a code allocator to type '%s'", ast.type_name(node.data_type))
      return false
    }

    if len(ctx.scope.path) == 2 && node.allocator.value == "stack" && !ctx.within_procedure_type
    {
      src.print_position_message(node.src_position, "Cannot apply a stack allocator to a module-level value")
      return false
    }

    if slice.contains(core_allocator_names, node.allocator.value)
    {
      node.allocator = ctx.program.identifiers[node.allocator.value]
      return true
    }
  }

  type_check_rhs_expression(ctx, node.allocator, nil) or_return

  _, code_allocator := ast.coerce_type(node.allocator.data_type, ctx.program.identifiers["code_allocator"])
  _, memory_allocator := ast.coerce_type(node.allocator.data_type, ctx.program.identifiers["memory_allocator"])

  if node.data_type.type != .kernel_type && code_allocator
  {
    src.print_position_message(node.src_position, "Custom code allocators can only be applied to kernels")
    return false
  }

  if len(ctx.scope.path) == 2 && memory_allocator
  {
    src.print_position_message(node.src_position, "Cannot apply a memory allocator to a module-level value")
    return false
  }

  if !code_allocator && !memory_allocator
  {
    src.print_position_message(node.src_position, "Cannot apply allocator with type '%s'", ast.type_name(node.allocator.data_type))
    return false
  }

  return true
}
