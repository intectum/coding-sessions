package generation

import "core:fmt"
import "core:os"
import "core:slice"

import "../ast"
import "../type_checking"

generate_expression :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context, register_num: int = 0) -> location
{
  expression_ctx := copy_gen_context(ctx, true)

  location := generate_expression_1(file, node, &expression_ctx, register_num, contains_allocations(node))

  close_gen_context(file, ctx, &expression_ctx, "expression", true)

  return location
}

generate_expression_1 :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
  _, binary_operator := slice.linear_search(ast.binary_operators, node.type)
  if !binary_operator
  {
    return generate_primary(file, node, ctx, register_num, contains_allocations)
  }

  lhs_node := &node.children[0]
  rhs_node := &node.children[1]

  operand_type_node := ast.get_type(lhs_node)
  result_type_node := ast.get_type(node)

  lhs_register_num := register_num
  rhs_register_num := lhs_register_num + 1

  lhs_location := generate_expression_1(file, lhs_node, ctx, lhs_register_num, contains_allocations)
  rhs_location := generate_expression_1(file, rhs_node, ctx, rhs_register_num, contains_allocations)

  if operand_type_node.value == "bool"
  {
    return generate_expression_bool(file, node, lhs_location, rhs_location, operand_type_node, ctx, register_num, contains_allocations)
  }

  _, float_type := slice.linear_search(type_checking.float_types, operand_type_node.value)
  if float_type
  {
    return generate_expression_float(file, node, lhs_location, rhs_location, operand_type_node, result_type_node, ctx, register_num, contains_allocations)
  }

  _, atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, operand_type_node.value)
  if atomic_integer_type
  {
    return generate_expression_atomic_integer(file, node, lhs_location, rhs_location, operand_type_node, result_type_node, ctx, register_num, contains_allocations)
  }

  _, signed_integer_type := slice.linear_search(type_checking.signed_integer_types, operand_type_node.value)
  if signed_integer_type
  {
    return generate_expression_signed_integer(file, node, lhs_location, rhs_location, operand_type_node, result_type_node, ctx, register_num, contains_allocations)
  }

  assert(false, "Failed to generate expression")
  return {}
}

generate_expression_bool :: proc(file: os.Handle, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
  _, comparison_operator := slice.linear_search(ast.comparison_operators, node.type)
  if comparison_operator
  {
    result_location := register(register_num, operand_type_node)
    lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node)

    fmt.fprintfln(file, "  cmp %s, %s ; compare", to_operand(lhs_register_location), to_operand(rhs_location))

    #partial switch node.type
    {
    case .equal:
      fmt.fprintfln(file, "  sete %s ; equal", to_operand(result_location))
    case .not_equal:
      fmt.fprintfln(file, "  setne %s ; not equal", to_operand(result_location))
    case:
      assert(false, "Failed to generate expression")
    }

    return result_location
  }

  result_location := register(register_num, operand_type_node)
  copy(file, lhs_location, result_location, operand_type_node)

  #partial switch node.type
  {
  case .and:
    fmt.fprintfln(file, "  and %s, %s ; and", to_operand(result_location), to_operand(rhs_location))
  case .or:
    fmt.fprintfln(file, "  or %s, %s ; or", to_operand(result_location), to_operand(rhs_location))
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}

generate_expression_float :: proc(file: os.Handle, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
  precision := to_precision_size(to_byte_size(operand_type_node))

  _, comparison_operator := slice.linear_search(ast.comparison_operators, node.type)
  if comparison_operator
  {
    lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node)
    result_location := register(register_num, result_type_node)

    fmt.fprintfln(file, "  ucomis%s %s, %s ; compare", precision, to_operand(lhs_register_location), to_operand(rhs_location))

    #partial switch node.type
    {
    case .equal:
      fmt.fprintfln(file, "  sete %s ; equal", to_operand(result_location))
    case .not_equal:
      fmt.fprintfln(file, "  setne %s ; not equal", to_operand(result_location))
    case .less_than:
      fmt.fprintfln(file, "  setb %s ; less than", to_operand(result_location))
    case .greater_than:
      fmt.fprintfln(file, "  seta %s ; greater than", to_operand(result_location))
    case .less_than_or_equal:
      fmt.fprintfln(file, "  setbe %s ; less than or equal", to_operand(result_location))
    case .greater_than_or_equal:
      fmt.fprintfln(file, "  setae %s ; greater than or equal", to_operand(result_location))
    case:
      assert(false, "Failed to generate expression")
    }

    return result_location
  }

  result_location := copy_to_register(file, lhs_location, register_num, result_type_node)

  #partial switch node.type
  {
  case .add:
    fmt.fprintfln(file, "  adds%s %s, %s ; add", precision, to_operand(result_location), to_operand(rhs_location))
  case .subtract:
    fmt.fprintfln(file, "  subs%s %s, %s ; subtract", precision, to_operand(result_location), to_operand(rhs_location))
  case .multiply:
    fmt.fprintfln(file, "  muls%s %s, %s ; multiply", precision, to_operand(result_location), to_operand(rhs_location))
  case .divide:
    fmt.fprintfln(file, "  divs%s %s, %s ; divide", precision, to_operand(result_location), to_operand(rhs_location))
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}

generate_expression_atomic_integer :: proc(file: os.Handle, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
  result_location := register(register_num, result_type_node)
  lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node)

  fmt.fprintfln(file, "  cmp %s, %s ; compare", to_operand(lhs_register_location), to_operand(rhs_location))

  #partial switch node.type
  {
  case .equal:
    fmt.fprintfln(file, "  sete %s ; equal", to_operand(result_location))
  case .not_equal:
    fmt.fprintfln(file, "  setne %s ; not equal", to_operand(result_location))
  case .less_than:
    fmt.fprintfln(file, "  setl %s ; less than", to_operand(result_location))
  case .greater_than:
    fmt.fprintfln(file, "  setg %s ; greater than", to_operand(result_location))
  case .less_than_or_equal:
    fmt.fprintfln(file, "  setle %s ; less than or equal", to_operand(result_location))
  case .greater_than_or_equal:
    fmt.fprintfln(file, "  setge %s ; greater than or equal", to_operand(result_location))
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}

generate_expression_signed_integer :: proc(file: os.Handle, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
  result_location := register(register_num, result_type_node)

  _, comparison_operator := slice.linear_search(ast.comparison_operators, node.type)
  if comparison_operator
  {
    lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node)

    fmt.fprintfln(file, "  cmp %s, %s ; compare", to_operand(lhs_register_location), to_operand(rhs_location))

    #partial switch node.type
    {
    case .equal:
      fmt.fprintfln(file, "  sete %s ; equal", to_operand(result_location))
    case .not_equal:
      fmt.fprintfln(file, "  setne %s ; not equal", to_operand(result_location))
    case .less_than:
      fmt.fprintfln(file, "  setl %s ; less than", to_operand(result_location))
    case .greater_than:
      fmt.fprintfln(file, "  setg %s ; greater than", to_operand(result_location))
    case .less_than_or_equal:
      fmt.fprintfln(file, "  setle %s ; less than or equal", to_operand(result_location))
    case .greater_than_or_equal:
      fmt.fprintfln(file, "  setge %s ; greater than or equal", to_operand(result_location))
    case:
      assert(false, "Failed to generate expression")
    }

    return result_location
  }

  #partial switch node.type
  {
  case .add:
    result_location = copy_to_register(file, lhs_location, register_num, result_type_node)
    fmt.fprintfln(file, "  add %s, %s ; add", to_operand(result_location), to_operand(rhs_location))
  case .subtract:
    result_location = copy_to_register(file, lhs_location, register_num, result_type_node)
    fmt.fprintfln(file, "  sub %s, %s ; subtract", to_operand(result_location), to_operand(rhs_location))
  case .multiply:
    result_location = copy_to_register(file, lhs_location, register_num, result_type_node)
    fmt.fprintfln(file, "  imul %s, %s ; multiply", to_operand(result_location), to_operand(rhs_location))
  case .divide, .modulo:
    // dividend / divisor

    operation_name := "divide"
    output_register_name := "ax"
    if node.type == .modulo
    {
      operation_name = "modulo"
      output_register_name = "dx"
    }

    rhs_register_location := copy_to_non_immediate(file, rhs_location, register_num + 1, result_type_node)
    output_register := register(output_register_name, result_type_node)
    fmt.fprintfln(file, "  mov %s, 0 ; %s: assign zero to dividend high part", to_operand(register("dx", result_type_node)), operation_name)
    fmt.fprintfln(file, "  mov %s, %s ; %s: assign lhs to dividend low part", to_operand(register("ax", result_type_node)), to_operand(lhs_location), operation_name)
    fmt.fprintfln(file, "  idiv %s %s ; %s", to_operation_size(to_byte_size(result_type_node)), to_operand(rhs_register_location), operation_name)
    fmt.fprintfln(file, "  mov %s, %s ; %s: assign result", to_operand(result_location), to_operand(output_register), operation_name)
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}
