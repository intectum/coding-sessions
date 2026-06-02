package type_checking

import "core:fmt"
import "core:slice"
import "core:strings"

import "../ast"
import "../src"

type_check_call :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  procedure_node := node.children[0]

  if ast.is_type(procedure_node)
  {
    return type_check_conversion_call(ctx, node)
  }

  procedure_type_node := procedure_node.data_type
  if procedure_type_node.type != .procedure_type
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

  call_ctx := start_anonymous_scope(ctx)
  placeholder_identifiers: map[string]^ast.node
  concrete_procedure := new(ast.scope)

  _, declaration_path := ast.get_declaration(call_ctx.program, call_ctx.scope, procedure_node)
  procedure_path: [dynamic]string
  append(&procedure_path, ..declaration_path)
  append(&procedure_path, procedure_node.value)

  param_expression_nodes := node.children[1:]
  for param_expression_node, index in param_expression_nodes
  {
    param_node := params_type_node.children[index]
    param_lhs_node := param_node.children[0]

    type_check_rhs_expression(&call_ctx, param_expression_node, param_lhs_node.data_type) or_return

    if resolve_placeholders(param_lhs_node.data_type, param_expression_node.data_type, &placeholder_identifiers)
    {
      if len(concrete_procedure.statements) == 0
      {
        procedure := ast.get_scope(call_ctx.program, procedure_path[:])

        append(&concrete_procedure.statements, ast.clone_node(procedure.statements[0]))
        node.children[0].data_type = concrete_procedure.statements[0].children[0].data_type
        procedure_type_node = node.children[0].data_type
        params_type_node = procedure_type_node.children[0]
      }

      for key, value in placeholder_identifiers do call_ctx.scope.identifiers[key] = value
      ast.resolve_types(call_ctx.program, call_ctx.scope, procedure_type_node) or_return
    }
  }

  end_anonymous_scope(ctx, &call_ctx)

  if len(procedure_type_node.children) == 2
  {
    node.data_type = procedure_type_node.children[1]
  }

  if len(concrete_procedure.statements) > 0
  {
    name: strings.Builder
    strings.builder_init(&name)
    defer strings.builder_destroy(&name)

    fmt.sbprintf(&name, "%s.$variant", procedure_node.value)
    for _, value in placeholder_identifiers
    {
      fmt.sbprintf(&name, ".%s", ast.type_var_name(value))
    }

    procedure_node.value = strings.clone(strings.to_string(name))
    procedure_path[len(procedure_path) - 1] = procedure_node.value

    if ast.get_scope(ctx.program, procedure_path[:]) == nil
    {
      for key, value in placeholder_identifiers do concrete_procedure.identifiers[key] = value

      parent_scope := ast.get_scope(ctx.program, declaration_path[:])
      parent_scope.identifiers[procedure_node.value] = concrete_procedure.statements[0].children[0]
      parent_scope.children[procedure_node.value] = concrete_procedure

      concrete_procedure.path = procedure_path[:]
      reference(ctx, declaration_path, procedure_node.value)
    }
  }

  return true
}

type_check_conversion_call :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  procedure_node := node.children[0]

  if 1 != len(node.children) - 1
  {
    src.print_position_message(node.src_position, "Wrong number of parameters passed to procedure '%s' (expected %i, found %i)", procedure_node.value, 1, len(node.children) - 1)
    return false
  }

  param_node := node.children[1]

  type_check_rhs_expression(ctx, param_node, nil) or_return

  _, param_numerical_type := slice.linear_search(ast.numerical_types, param_node.data_type.value)
  _, return_numerical_type := slice.linear_search(ast.numerical_types, procedure_node.value)
  if !param_numerical_type && !return_numerical_type
  {
    src.print_position_message(node.src_position, "Type '%s' cannot be converted to type '%s'", param_node.data_type.value, procedure_node.value)
    return false
  }

  ast.upgrade_types(ctx.program, param_node, param_node.data_type.value == "[any_float]" ? ctx.program.identifiers["f64"] : ctx.program.identifiers["i64"]) or_return

  node.data_type = ast.clone_node(procedure_node)

  procedure_type_node := ast.make_node({ type = .procedure_type })
  append(&procedure_type_node.children, ast.make_node({ type = .group, value = "[parameters]" }))
  append(&procedure_type_node.children[0].children, ast.make_node({ type = .identifier, value = "value", data_type = param_node.data_type }))
  append(&procedure_type_node.children, ast.clone_node(procedure_node))
  procedure_node.data_type = procedure_type_node

  return true
}
