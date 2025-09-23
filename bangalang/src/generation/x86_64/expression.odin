package x86_64

import "core:fmt"
import "core:slice"

import "../../ast"
import "../../type_checking"
import ".."

generate_expression :: proc(ctx: ^generation.gen_context, node: ^ast.node, register_num: int = 0) -> location
{
  initial_stack_size := ctx.stack_size

  location := generate_expression_1(ctx, node, register_num, contains_allocations(node))

  deallocate_stack(ctx, ctx.stack_size - initial_stack_size)

  return location
}

generate_expression_1 :: proc(ctx: ^generation.gen_context, node: ^ast.node, register_num: int, contains_allocations: bool) -> location
{
  _, binary_operator := slice.linear_search(ast.binary_operators, node.type)
  if !binary_operator
  {
    return generate_primary(ctx, node, register_num, contains_allocations)
  }

  lhs_node := &node.children[0]
  rhs_node := &node.children[1]

  operand_type_node := ast.get_type(lhs_node)
  result_type_node := ast.get_type(node)

  lhs_register_num := register_num
  rhs_register_num := lhs_register_num + 1

  lhs_location := generate_expression_1(ctx, lhs_node, lhs_register_num, contains_allocations)
  rhs_location := generate_expression_1(ctx, rhs_node, rhs_register_num, contains_allocations)

  if operand_type_node.value == "bool"
  {
    return generate_expression_bool(ctx, node, lhs_location, rhs_location, operand_type_node, register_num, contains_allocations)
  }

  _, float_type := slice.linear_search(type_checking.float_types, operand_type_node.value)
  if float_type
  {
    return generate_expression_float(ctx, node, lhs_location, rhs_location, operand_type_node, result_type_node, register_num, contains_allocations)
  }

  _, atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, operand_type_node.value)
  if atomic_integer_type
  {
    return generate_expression_atomic_integer(ctx, node, lhs_location, rhs_location, operand_type_node, result_type_node, register_num, contains_allocations)
  }

  _, signed_integer_type := slice.linear_search(type_checking.signed_integer_types, operand_type_node.value)
  if signed_integer_type
  {
    return generate_expression_signed_integer(ctx, node, lhs_location, rhs_location, operand_type_node, result_type_node, register_num, contains_allocations)
  }

  assert(false, "Failed to generate expression")
  return {}
}

generate_expression_bool :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, register_num: int, contains_allocations: bool) -> location
{
  _, comparison_operator := slice.linear_search(ast.comparison_operators, node.type)
  if comparison_operator
  {
    result_location := register(register_num, operand_type_node)
    lhs_register_location := copy_to_register(ctx, lhs_location, register_num, operand_type_node)

    fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare", to_operand(lhs_register_location), to_operand(rhs_location))

    #partial switch node.type
    {
    case .equal:
      fmt.sbprintfln(&ctx.output, "  sete %s ; equal", to_operand(result_location))
    case .not_equal:
      fmt.sbprintfln(&ctx.output, "  setne %s ; not equal", to_operand(result_location))
    case:
      assert(false, "Failed to generate expression")
    }

    return result_location
  }

  result_location := register(register_num, operand_type_node)
  copy(ctx, lhs_location, result_location, operand_type_node)

  #partial switch node.type
  {
  case .and:
    fmt.sbprintfln(&ctx.output, "  and %s, %s ; and", to_operand(result_location), to_operand(rhs_location))
  case .or:
    fmt.sbprintfln(&ctx.output, "  or %s, %s ; or", to_operand(result_location), to_operand(rhs_location))
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}

generate_expression_float :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, register_num: int, contains_allocations: bool) -> location
{
  precision := to_precision_size(to_byte_size(operand_type_node))

  _, comparison_operator := slice.linear_search(ast.comparison_operators, node.type)
  if comparison_operator
  {
    lhs_register_location := copy_to_register(ctx, lhs_location, register_num, operand_type_node)
    result_location := register(register_num, result_type_node)

    fmt.sbprintfln(&ctx.output, "  ucomis%s %s, %s ; compare", precision, to_operand(lhs_register_location), to_operand(rhs_location))

    #partial switch node.type
    {
    case .equal:
      fmt.sbprintfln(&ctx.output, "  sete %s ; equal", to_operand(result_location))
    case .not_equal:
      fmt.sbprintfln(&ctx.output, "  setne %s ; not equal", to_operand(result_location))
    case .less_than:
      fmt.sbprintfln(&ctx.output, "  setb %s ; less than", to_operand(result_location))
    case .greater_than:
      fmt.sbprintfln(&ctx.output, "  seta %s ; greater than", to_operand(result_location))
    case .less_than_or_equal:
      fmt.sbprintfln(&ctx.output, "  setbe %s ; less than or equal", to_operand(result_location))
    case .greater_than_or_equal:
      fmt.sbprintfln(&ctx.output, "  setae %s ; greater than or equal", to_operand(result_location))
    case:
      assert(false, "Failed to generate expression")
    }

    return result_location
  }

  result_location := copy_to_register(ctx, lhs_location, register_num, result_type_node)

  #partial switch node.type
  {
  case .add:
    fmt.sbprintfln(&ctx.output, "  adds%s %s, %s ; add", precision, to_operand(result_location), to_operand(rhs_location))
  case .subtract:
    fmt.sbprintfln(&ctx.output, "  subs%s %s, %s ; subtract", precision, to_operand(result_location), to_operand(rhs_location))
  case .multiply:
    fmt.sbprintfln(&ctx.output, "  muls%s %s, %s ; multiply", precision, to_operand(result_location), to_operand(rhs_location))
  case .divide:
    fmt.sbprintfln(&ctx.output, "  divs%s %s, %s ; divide", precision, to_operand(result_location), to_operand(rhs_location))
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}

generate_expression_atomic_integer :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, register_num: int, contains_allocations: bool) -> location
{
  result_location := register(register_num, result_type_node)
  lhs_register_location := copy_to_register(ctx, lhs_location, register_num, operand_type_node)

  fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare", to_operand(lhs_register_location), to_operand(rhs_location))

  #partial switch node.type
  {
  case .equal:
    fmt.sbprintfln(&ctx.output, "  sete %s ; equal", to_operand(result_location))
  case .not_equal:
    fmt.sbprintfln(&ctx.output, "  setne %s ; not equal", to_operand(result_location))
  case .less_than:
    fmt.sbprintfln(&ctx.output, "  setl %s ; less than", to_operand(result_location))
  case .greater_than:
    fmt.sbprintfln(&ctx.output, "  setg %s ; greater than", to_operand(result_location))
  case .less_than_or_equal:
    fmt.sbprintfln(&ctx.output, "  setle %s ; less than or equal", to_operand(result_location))
  case .greater_than_or_equal:
    fmt.sbprintfln(&ctx.output, "  setge %s ; greater than or equal", to_operand(result_location))
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}

generate_expression_signed_integer :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, register_num: int, contains_allocations: bool) -> location
{
  result_location := register(register_num, result_type_node)

  _, comparison_operator := slice.linear_search(ast.comparison_operators, node.type)
  if comparison_operator
  {
    lhs_register_location := copy_to_register(ctx, lhs_location, register_num, operand_type_node)

    fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare", to_operand(lhs_register_location), to_operand(rhs_location))

    #partial switch node.type
    {
    case .equal:
      fmt.sbprintfln(&ctx.output, "  sete %s ; equal", to_operand(result_location))
    case .not_equal:
      fmt.sbprintfln(&ctx.output, "  setne %s ; not equal", to_operand(result_location))
    case .less_than:
      fmt.sbprintfln(&ctx.output, "  setl %s ; less than", to_operand(result_location))
    case .greater_than:
      fmt.sbprintfln(&ctx.output, "  setg %s ; greater than", to_operand(result_location))
    case .less_than_or_equal:
      fmt.sbprintfln(&ctx.output, "  setle %s ; less than or equal", to_operand(result_location))
    case .greater_than_or_equal:
      fmt.sbprintfln(&ctx.output, "  setge %s ; greater than or equal", to_operand(result_location))
    case:
      assert(false, "Failed to generate expression")
    }

    return result_location
  }

  #partial switch node.type
  {
  case .add:
    result_location = copy_to_register(ctx, lhs_location, register_num, result_type_node)
    fmt.sbprintfln(&ctx.output, "  add %s, %s ; add", to_operand(result_location), to_operand(rhs_location))
  case .subtract:
    result_location = copy_to_register(ctx, lhs_location, register_num, result_type_node)
    fmt.sbprintfln(&ctx.output, "  sub %s, %s ; subtract", to_operand(result_location), to_operand(rhs_location))
  case .multiply:
    result_location = copy_to_register(ctx, lhs_location, register_num, result_type_node)
    fmt.sbprintfln(&ctx.output, "  imul %s, %s ; multiply", to_operand(result_location), to_operand(rhs_location))
  case .divide, .modulo:
    // dividend / divisor

    operation_name := "divide"
    output_register_name := "ax"
    if node.type == .modulo
    {
      operation_name = "modulo"
      output_register_name = "dx"
    }

    rhs_register_location := copy_to_non_immediate(ctx, rhs_location, register_num + 1, result_type_node)
    output_register := register(output_register_name, result_type_node)
    fmt.sbprintfln(&ctx.output, "  mov %s, 0 ; %s: assign zero to dividend high part", to_operand(register("dx", result_type_node)), operation_name)
    fmt.sbprintfln(&ctx.output, "  mov %s, %s ; %s: assign lhs to dividend low part", to_operand(register("ax", result_type_node)), to_operand(lhs_location), operation_name)
    fmt.sbprintfln(&ctx.output, "  idiv %s %s ; %s", to_operation_size(to_byte_size(result_type_node)), to_operand(rhs_register_location), operation_name)
    fmt.sbprintfln(&ctx.output, "  mov %s, %s ; %s: assign result", to_operand(result_location), to_operand(output_register), operation_name)
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}
