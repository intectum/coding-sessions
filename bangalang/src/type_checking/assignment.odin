package type_checking

import "core:slice"
import "core:strings"

import "../ast"
import "../src"

type_check_assignment :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  lhs_node := &node.children[0]
  declaration := ast.get_type(lhs_node) != nil

  type_check_lhs_expression(lhs_node, ctx) or_return

  if len(node.children) == 1 && ast.is_static_procedure(lhs_node) && ast.get_type(lhs_node).directive != "#extern"
  {
    src.print_position_message(lhs_node.src_position, "Procedure '%s' must have a procedure body", lhs_node.value)
    return false
  }

  if ast.is_static_procedure(lhs_node)
  {
    found_default := false
    lhs_type_node := ast.get_type(lhs_node)
    params_type_node := lhs_type_node.children[0]
    for &param_node in params_type_node.children
    {
      if len(param_node.children) == 1 && found_default
      {
        src.print_position_message(lhs_node.src_position, "Procedure parameters with defaults cannot be followed by parameters without defaults")
        return false
      }

      if len(param_node.children) > 1
      {
        found_default = true
      }

      param_lhs_node := &param_node.children[0]
      param_lhs_node.allocator = "stack"

      type_check_assignment(&param_node, ctx) or_return
    }
  }

  if len(node.children) > 1
  {
    operator_node := &node.children[1]
    rhs_node := &node.children[2]

    lhs_type_node := ast.get_type(lhs_node)
    if ast.is_static_procedure(lhs_node)
    {
      if lhs_type_node.directive == "#extern"
      {
        src.print_position_message(lhs_node.src_position, "#extern procedure '%s' cannot have a procedure body", lhs_node.value)
        return false
      }

      return_type_node := len(lhs_type_node.children) == 2 ? &lhs_type_node.children[1] : nil
      if return_type_node != nil && rhs_node.type != .if_statement && rhs_node.type != .for_statement && rhs_node.type != .scope_statement && rhs_node.type != .return_statement && rhs_node.type != .assignment_statement
      {
        return_node := ast.node {
          type = .return_statement,
          src_position = rhs_node.src_position
        }
        append(&return_node.children, rhs_node^)
        rhs_node^ = return_node
      }

      wrap_in_scope(rhs_node)
      type_check_statements(ctx, rhs_node.children[:]) or_return
    }
    else
    {
      if rhs_node.type == .scope_statement
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
    if lhs_type_node.value == "[none]"
    {
      append(&lhs_node.children, rhs_type_node^)
    }

    if operator_node.type != .assign
    {
      if declaration
      {
        src.print_position_message(operator_node.src_position, "Assignment operator '%s' is not valid for declarations", operator_node.value)
        return false
      }

      _, numerical_type := slice.linear_search(numerical_types, rhs_type_node.value)
      if rhs_type_node.value == "[array]" || rhs_type_node.value == "[slice]"
      {
        element_type_node := &rhs_type_node.children[0]
        _, float_type := slice.linear_search(float_types, element_type_node.value)
        if !float_type || operator_node.type == .bitwise_and_assign || operator_node.type == .bitwise_or_assign || operator_node.type == .modulo_assign
        {
          src.print_position_message(operator_node.src_position, "Assignment operator '%s' is not valid for type '%s'", operator_node.value, type_name(rhs_type_node))
          return false
        }
      }
      else if !numerical_type
      {
        src.print_position_message(operator_node.src_position, "Assignment operator '%s' is not valid for type '%s'", operator_node.value, type_name(rhs_type_node))
        return false
      }

      _, float_type := slice.linear_search(float_types, rhs_type_node.value)
      if float_type && (operator_node.type == .bitwise_and_assign || operator_node.type == .bitwise_or_assign || operator_node.type == .modulo_assign)
      {
        src.print_position_message(operator_node.src_position, "Assignment operator '%s' is not valid for type '%s", operator_node.value, type_name(rhs_type_node))
        return false
      }

      _, atomic_integer_type := slice.linear_search(atomic_integer_types, rhs_type_node.value)
      if atomic_integer_type && operator_node.type != .add_assign && operator_node.type != .subtract_assign
      {
        src.print_position_message(operator_node.src_position, "Assignment operator '%s' is not valid for type '%s'", operator_node.value, type_name(rhs_type_node))
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

  identifier_node, _ := get_identifier_node(ctx, lhs_node.value)
  if !ast.is_member(lhs_node) && identifier_node == nil
  {
    allocator := ast.get_allocator(lhs_node)
    if allocator == "heap" || allocator == "vram"
    {
      if len(node.children) > 1
      {
        src.print_position_message(lhs_node.src_position, "Cannot assign when using allocator '%s'", allocator)
        return false
      }

      length_expression_node: ^ast.node
      if lhs_type_node.value == "[array]"
      {
        length_expression_node = &lhs_type_node.children[1]

        lhs_type_node.value = "[slice]"
        resize(&lhs_type_node.children, 1)
      }
      else
      {
        reference_node: ast.node = { type = .reference }
        append(&reference_node.children, lhs_type_node^)
        lhs_type_node^ = reference_node
      }

      operator_node := ast.node { type = .assign, value = "=" }
      append(&node.children, operator_node)

      allocator_node := ast.node { type = .call, directive = "#danger_untyped" }
      append(&allocator_node.children, ast.node { type = .identifier, value = strings.concatenate({ "allocate_", allocator }) })
      append(&allocator_node.children[0].children, ast.node { type = .identifier, value = "memory" })

      if lhs_type_node.value == "[slice]"
      {
        append(&allocator_node.children, ast.node { type = .multiply, value = "*" })
        append(&allocator_node.children[1].children, ast.node { type = .number_literal })
        append(&allocator_node.children[1].children, length_expression_node^)

        rhs_node: ast.node = { type = .compound_literal }
        append(&rhs_node.children, ast.node { type = .assignment_statement })
        append(&rhs_node.children[0].children, ast.node { type = .identifier, value = "raw" })
        append(&rhs_node.children[0].children, ast.node { type = .assign, value = "=" })
        append(&rhs_node.children[0].children, allocator_node)
        append(&rhs_node.children, ast.node { type = .assignment_statement })
        append(&rhs_node.children[1].children, ast.node { type = .identifier, value = "length" })
        append(&rhs_node.children[1].children, ast.node { type = .assign, value = "=" })
        append(&rhs_node.children[1].children, length_expression_node^)
        append(&node.children, rhs_node)
      }
      else
      {
        append(&allocator_node.children, ast.node { type = .number_literal })
        append(&node.children, allocator_node)
      }

      if contains_non_fixed_array_sizes(lhs_type_node)
      {
        src.print_position_message(lhs_node.src_position, "Type '%s' cannot contain non-fixed array sizes", type_name(lhs_type_node))
        return false
      }

      type_check_rhs_expression(&node.children[2], ctx, lhs_type_node) or_return
    }

    ctx.identifiers[lhs_node.value] = lhs_node^
  }

  return true
}

contains_non_fixed_array_sizes :: proc(type_node: ^ast.node) -> bool
{
  if type_node.value == "[array]" && type_node.children[1].type != .number_literal
  {
    return true
  }

  for &child_node in type_node.children
  {
    if contains_non_fixed_array_sizes(&child_node)
    {
      return true
    }
  }

  return false
}
