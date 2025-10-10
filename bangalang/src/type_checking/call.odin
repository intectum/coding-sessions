package type_checking

import "core:fmt"
import "core:slice"

import "../ast"
import "../src"

type_check_call :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  child_index := 0
  procedure_node := &node.children[child_index]
  child_index += 1

  if ast.is_type(procedure_node)
  {
    if 1 != len(node.children) - 1
    {
      src.print_position_message(node.src_position, "Wrong number of parameters passed to procedure '%s' (expected %i, found %i)", procedure_node.value, 1, len(node.children) - 1)
      return false
    }

    param_node := &node.children[child_index]
    child_index += 1

    type_check_rhs_expression(param_node, ctx, nil) or_return

    param_type_node := ast.get_type(param_node)
    _, param_numerical_type := slice.linear_search(numerical_types, param_type_node.value)
    _, return_numerical_type := slice.linear_search(numerical_types, procedure_node.value)
    if !param_numerical_type && !return_numerical_type
    {
      src.print_position_message(node.src_position, "Type '%s' cannot be converted to type '%s'", param_type_node.value, procedure_node.value)
      return false
    }

    append(&node.children, procedure_node^)

    type_node := ast.node { type = .type, value = "[procedure]" }
    append(&type_node.children, ast.node { type = .type, value = "[parameters]" })
    append(&type_node.children[0].children, ast.node { type = .identifier, value = "value" })
    append(&type_node.children[0].children[0].children, param_type_node^)
    append(&type_node.children, procedure_node^)
    append(&procedure_node.children, type_node)

    return true
  }

  procedure_type_node := ast.get_type(procedure_node)
  if procedure_type_node.value != "[procedure]"
  {
    src.print_position_message(node.src_position, "'%s' does not refer to a procedure", procedure_node.value)
    return false
  }

  params_type_node := procedure_type_node.children[0]
  actual_param_count := len(node.children) - 1
  max_param_count := len(params_type_node.children)
  min_param_count := 0
  for min_param_count < max_param_count && len(params_type_node.children[min_param_count].children) == 1
  {
    min_param_count += 1
  }

  if actual_param_count < min_param_count || actual_param_count > max_param_count
  {
    expected := min_param_count < max_param_count ? fmt.aprintf("%i-%i", min_param_count, max_param_count) : fmt.aprintf("%i", min_param_count)
    src.print_position_message(node.src_position, "Wrong number of parameters passed to procedure '%s' (expected %s, found %i)", procedure_node.value, expected, actual_param_count)
    return false
  }

  for child_index < len(node.children)
  {
    param_node_from_type := &params_type_node.children[child_index - 1]
    param_lhs_node_from_type := &param_node_from_type.children[0]

    param_node := &node.children[child_index]
    child_index += 1

    type_check_rhs_expression(param_node, ctx, ast.get_type(param_lhs_node_from_type)) or_return
  }

  if len(procedure_type_node.children) == 2
  {
    return_type_node := &procedure_type_node.children[1]
    append(&node.children, return_type_node^)
  }

  return true
}
