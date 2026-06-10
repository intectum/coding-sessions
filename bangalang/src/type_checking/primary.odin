package type_checking

import "core:slice"
import "core:strconv"
import "core:strings"

import "../ast"
import "../src"

complex_primaries: []ast.node_type = { .compound_literal, .enum_type, .kernel_type, .procedure_type, .struct_type }

type_check_primary :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  if ctx.within_struct_type && node.type == .reference do return true

  if !slice.contains(complex_primaries, node.type) && len(node.children) > 0
  {
    type_check_primary(ctx, node.children[0]) or_return
  }

  if node.modifier != nil
  {
    type_check_modifier(ctx, node.modifier) or_return
  }

  #partial switch node.type
  {
  case .reference:
    if ctx.within_kernel
    {
      src.print_position_message(node.src_position, "Kernels do not support pointers")
      return false
    }

    if ast.is_type(node.children[0]) do return true

    _, literal := slice.linear_search(ast.literals, node.children[0].type)
    if literal
    {
      src.print_position_message(node.src_position, "Cannot reference '%s' literal", node.children[0].type)
      return false
    }

    type_node := ast.make_node({ type = .reference })
    append(&type_node.children, node.children[0].data_type)
    node.data_type = type_node
  case .negate:
    child_type_node := node.children[0].data_type
    _, numerical_type := slice.linear_search(ast.numerical_types, child_type_node.value)
    _, unsigned_integer_type := slice.linear_search(ast.unsigned_integer_types, child_type_node.value)
    if !numerical_type || unsigned_integer_type
    {
      src.print_position_message(node.src_position, "Cannot negate type '%s'", ast.type_name(child_type_node))
      return false
    }

    node.data_type = child_type_node
  case .not:
    child_type_node := node.children[0].data_type
    if child_type_node.value != "bool"
    {
      src.print_position_message(node.src_position, "Cannot invert type '%s'", ast.type_name(child_type_node))
      return false
    }

    node.data_type = child_type_node
  case .dereference:
    if ctx.within_kernel
    {
      src.print_position_message(node.src_position, "Kernels do not support pointers")
      return false
    }

    child_type_node := node.children[0].data_type
    if child_type_node.type != .reference
    {
      src.print_position_message(node.src_position, "Cannot dereference type '%s'", ast.type_name(child_type_node))
      return false
    }

    node.data_type = child_type_node.children[0]
  case .subscript:
    child_node := node.children[0]
    if ast.is_type(child_node) do return true

    auto_dereference(child_node)

    child_type_node := child_node.data_type
    if child_type_node.type != .subscript
    {
      src.print_position_message(node.src_position, "Cannot index type '%s'", ast.type_name(child_type_node))
      return false
    }

    index_type := ctx.program.identifiers["u32"]

    start_expression_node: ^ast.node
    end_expression_node: ^ast.node
    if node.children[1].type != .range
    {
      node.children[1] = auto_convert(node.children[1], index_type) or_return
      start_expression_node = node.children[1]
    }
    else
    {
      node.children[1].children[0] = auto_convert(node.children[1].children[0], index_type) or_return
      start_expression_node = node.children[1].children[0]

      node.children[1].children[1] = auto_convert(node.children[1].children[1], index_type) or_return
      end_expression_node = node.children[1].children[1]
    }

    type_check_rhs_expression(ctx, start_expression_node, index_type) or_return

    if node.children[1].type != .range
    {
      node.data_type = child_type_node.children[0]
    }
    else
    {
      type_check_rhs_expression(ctx, end_expression_node, index_type) or_return

      type_node := ast.make_node({ type = .subscript })
      append(&type_node.children, child_type_node.children[0])
      range_node := ast.make_node({ type = .range })
      append(&range_node.children, ast.make_node({ type = .nil_literal }))
      append(&range_node.children, ast.make_node({ type = .nil_literal }))
      append(&type_node.children, range_node)
      node.data_type = type_node
    }

    if ast.is_array(child_type_node)
    {
      length := strconv.atoi(child_type_node.children[1].value)

      if ast.get_modifier(child_node, "#danger_boundless") == nil && start_expression_node.type == .number_literal && strconv.atoi(start_expression_node.value) >= length
      {
        src.print_position_message(node.src_position, "Index %i out of bounds", strconv.atoi(start_expression_node.value))
        return false
      }
    }
  case .call:
    type_check_call(ctx, node) or_return
  case .identifier:
    type_check_identifier(ctx, node) or_return
  case .char_literal:
    node.data_type = ctx.program.identifiers["char"]
  case .string_literal:
    node.data_type = ast.make_node({ type = .identifier, value = "[any_string]" })
  case .number_literal:
    type := strings.contains(node.value, ".") ? "[any_float]" : "[any_number]"
    node.data_type = ast.make_node({ type = .identifier, value = type })
  case .boolean_literal:
    node.data_type = ctx.program.identifiers["bool"]
  case .compound_literal:
    type_check_compound_literal(ctx, node) or_return
  case .nil_literal:
    node.data_type = ast.make_node({ type = .identifier, value = "[none]" })
  case .enum_type:
    for member_node, index in node.children[:len(node.children) - 1]
    {
      for other_member_node in node.children[index + 1:]
      {
        if other_member_node.value == member_node.value
        {
          src.print_position_message(other_member_node.src_position, "Duplicate member '%s' found in type '%s'", other_member_node.value, ast.type_name(node))
          return false
        }
      }
    }
  case .kernel_type, .procedure_type:
    proc_ctx := start_anonymous_scope(ctx)
    defer end_anonymous_scope(ctx, &proc_ctx)
    proc_ctx.within_procedure_type = true

    found_default := false
    params_type_node := node.children[0]
    for param_node in params_type_node.children
    {
      if len(param_node.children) == 1 && found_default
      {
        src.print_position_message(node.src_position, "Procedure parameters with defaults cannot be followed by parameters without defaults")
        return false
      }

      if len(param_node.children) > 1
      {
        found_default = true
      }

      param_lhs_node := param_node.children[0]
      param_lhs_node.allocator = ctx.program.identifiers["stack"]

      type_check_assignment(&proc_ctx, param_node) or_return
    }

    if node.type == .kernel_type
    {
      if len(params_type_node.children) != 2
      {
        src.print_position_message(node.src_position, "Kernels must have two parameters")
        return false
      }

      if params_type_node.children[0].children[0].data_type.value != "u32"
      {
        src.print_position_message(node.src_position, "The first parameter of a kernel must be a 'u32'")
        return false
      }

      if !ast.is_slice(params_type_node.children[1].children[0].data_type)
      {
        src.print_position_message(node.src_position, "The second parameter of a kernel must be a slice")
        return false
      }

      if found_default
      {
        src.print_position_message(node.src_position, "Kernel parameters must not have defaults")
        return false
      }

      if len(node.children) > 1
      {
        src.print_position_message(node.src_position, "Kernels must not have a return type")
        return false
      }
    }

    if len(node.children) > 1
    {
      return_type_node := node.children[1]
      type_check_primary(&proc_ctx, return_type_node) or_return
    }
  case .struct_type:
    within_struct_type := ctx.within_struct_type
    ctx.within_struct_type = true

    success := true
    for member_node, index in node.children
    {
      if index < len(node.children) - 1
      {
        for other_member_node in node.children[index + 1:]
        {
          if other_member_node.value == member_node.value
          {
            src.print_position_message(other_member_node.src_position, "Duplicate member '%s' found in type '%s'", other_member_node.value, ast.type_name(node))
            success = false
          }
        }
      }

      if !type_check_primary(ctx, member_node.data_type)
      {
        success = false
      }
    }

    ctx.within_struct_type = within_struct_type

    if !success do return false
  case:
    type_check_rhs_expression_1(ctx, node) or_return
  }

  if ast.get_modifier(node, "#danger_untyped") != nil
  {
    node.data_type = ast.make_node({ type = .identifier, value= "[none]" })
  }

  return true
}
