package type_checking

import "core:slice"

import "../ast"
import "../src"
import strings "core:strings"

type_check_assignment :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  lhs_node := &node.children[0]

  type_check_lhs_expression(lhs_node, ctx) or_return

  if len(node.children) > 1
  {
    operator_node := &node.children[1]
    rhs_node := &node.children[2]

    lhs_type_node := ast.get_type(lhs_node)
    if !ast.is_member(lhs_node) && lhs_type_node != nil && lhs_type_node.value == "[procedure]"
    {
      if lhs_type_node.directive == "#extern"
      {
        src.print_position_message(lhs_node.src_position, "#extern procedure '%s' cannot have a procedure body", lhs_node.value)
        return false
      }

      params_type_node := lhs_type_node.children[0]
      for &param_node in params_type_node.children
      {
        param_node.allocator = "stack"
        ctx.identifiers[param_node.value] = param_node
      }

      return_type_node := len(lhs_type_node.children) == 2 ? &lhs_type_node.children[1] : nil
      if return_type_node != nil && rhs_node.type != .if_ && rhs_node.type != .for_ && rhs_node.type != .scope && rhs_node.type != .return_ && rhs_node.type != .assignment
      {
        return_node := ast.node {
          type = .return_,
          src_position = rhs_node.src_position
        }
        append(&return_node.children, rhs_node^)
        rhs_node^ = return_node
      }

      type_check_statement(rhs_node, ctx) or_return
    }
    else
    {
      if rhs_node.type == .scope
      {
        rhs_node.type = .compound_literal
      }

      _, statement := slice.linear_search(ast.statements, rhs_node.type)
      if statement
      {
        src.print_position_message(lhs_node.src_position, "Right-hand-side must be an expression")
        return false
      }

      type_check_rhs_expression(rhs_node, ctx, lhs_type_node) or_return
    }

    rhs_type_node := ast.get_type(rhs_node)
    if lhs_type_node == nil
    {
      append(&lhs_node.children, rhs_type_node^)
    }

    if operator_node.type != .assign
    {
      _, numerical_type := slice.linear_search(numerical_types, rhs_type_node.value)
      if rhs_type_node.value == "[array]" || rhs_type_node.value == "[slice]"
      {
        element_type_node := &rhs_type_node.children[0]
        _, float_type := slice.linear_search(float_types, element_type_node.value)
        if !float_type || operator_node.type == .modulo_assign
        {
          src.print_position_message(operator_node.src_position, "Assignment operator %s is not valid for type '%s'", operator_node.type, type_name(rhs_type_node))
          return false
        }
      }
      else if !numerical_type
      {
        src.print_position_message(operator_node.src_position, "Assignment operator %s is not valid for type '%s'", operator_node.type, type_name(rhs_type_node))
        return false
      }

      _, float_type := slice.linear_search(float_types, rhs_type_node.value)
      if float_type && operator_node.type == .modulo_assign
      {
        src.print_position_message(operator_node.src_position, "Assignment operator %s is not valid for type '%s", operator_node.type, type_name(rhs_type_node))
        return false
      }

      _, atomic_integer_type := slice.linear_search(atomic_integer_types, rhs_type_node.value)
      if atomic_integer_type && operator_node.type != .add_assign && operator_node.type != .subtract_assign
      {
        src.print_position_message(operator_node.src_position, "Assignment operator %s is not valid for type '%s'", operator_node.type, type_name(rhs_type_node))
        return false
      }
    }
  }

  lhs_type_node := ast.get_type(lhs_node)
  if lhs_type_node == nil || lhs_type_node.value == "[any_float]" || lhs_type_node.value == "[any_int]" || lhs_type_node.value == "[any_number]" || lhs_type_node.value == "[any_string]"
  {
    src.print_position_message(lhs_node.src_position, "Could not determine type of '%s'", lhs_node.value)
    return false
  }

  if !ast.is_member(lhs_node) && !(lhs_node.value in ctx.identifiers)
  {
    allocator := ast.get_allocator(lhs_node)
    if allocator == "heap" || allocator == "vram"
    {
      if lhs_type_node.type != .reference
      {
        src.print_position_message(lhs_node.src_position, "Cannot allocate non-reference type '%s' with allocator '%s'", lhs_type_node.value, allocator)
        return false
      }

      if len(node.children) > 1
      {
        src.print_position_message(lhs_node.src_position, "Cannot assign when using allocator '%s'", allocator)
        return false
      }

      operator_node := ast.node { type = .assign }
      append(&node.children, operator_node)

      allocator_node := ast.node { type = .call, src_position = node.src_position }
      append(&allocator_node.children, ast.node { type = .identifier, value = strings.concatenate({ "allocate_", allocator }), src_position = node.src_position })
      append(&allocator_node.children[0].children, ast.node { type = .identifier, value = "memory", src_position = node.src_position })
      append(&allocator_node.children, ast.node { type = .number, src_position = node.src_position })
      append(&node.children, allocator_node)

      type_check_rhs_expression(&node.children[2], ctx, nil)
    }

    ctx.identifiers[lhs_node.value] = lhs_node^
  }

  return true
}
