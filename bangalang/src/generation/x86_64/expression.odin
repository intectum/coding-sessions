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

  lhs_node := node.children[0]
  rhs_node := node.children[1]

  operand_type_node := lhs_node.data_type
  result_type_node := node.data_type

  lhs_register_num := register_num
  rhs_register_num := lhs_register_num + 1

  lhs_location := generate_expression_1(ctx, lhs_node, lhs_register_num, contains_allocations)
  rhs_location := generate_expression_1(ctx, rhs_node, rhs_register_num, contains_allocations)

  if operand_type_node.value == "[slice]"
  {
    return generate_expression_slice(ctx, node, lhs_location, rhs_location, operand_type_node, result_type_node, register_num)
  }

  if operand_type_node.value == "bool"
  {
    return generate_expression_bool(ctx, node, lhs_location, rhs_location, operand_type_node, register_num)
  }

  _, float_type := slice.linear_search(type_checking.float_types, operand_type_node.value)
  if float_type
  {
    return generate_expression_float(ctx, node, lhs_location, rhs_location, operand_type_node, result_type_node, register_num)
  }

  _, atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, operand_type_node.value)
  if atomic_integer_type
  {
    return generate_expression_atomic_integer(ctx, node, lhs_location, rhs_location, operand_type_node, result_type_node, register_num)
  }

  _, signed_integer_type := slice.linear_search(type_checking.signed_integer_types, operand_type_node.value)
  _, unsigned_integer_type := slice.linear_search(type_checking.unsigned_integer_types, operand_type_node.value)
  if signed_integer_type || unsigned_integer_type
  {
    return generate_expression_integer(ctx, node, lhs_location, rhs_location, operand_type_node, result_type_node, register_num)
  }

  return generate_expression_any(ctx, node, lhs_location, rhs_location, operand_type_node, result_type_node, register_num)
}

generate_expression_slice :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, register_num: int) -> location
{
  slice_cmp_index := ctx.next_index
  ctx.next_index += 1

  result_location := register(register_num, result_type_node)

  lhs_length_location := lhs_location
  if lhs_location.type != .immediate
  {
    lhs_length_location.offset += address_size
  }

  rhs_length_location := rhs_location
  if rhs_location.type != .immediate
  {
    rhs_length_location.offset += address_size
  }

  lhs_length_register_location := copy_to_register(ctx, lhs_length_location, register_num + 1, length_type_node)
  fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare lengths", to_operand(lhs_length_register_location), to_operand(rhs_length_location));
  fmt.sbprintfln(&ctx.output, "  jne .slice_cmp_%i_set ; lengths not equals", slice_cmp_index);

  nil_compare := lhs_location.type == .immediate || rhs_location.type == .immediate

  if lhs_location.type == .immediate
  {
    fmt.sbprintln(&ctx.output, "  mov al, 0 ; compare: lhs");
    fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; compare: rhs", to_operand(rhs_location));
    fmt.sbprintln(&ctx.output, "  mov rdi, [rdi] ; compare: rhs");
  }
  else if rhs_location.type == .immediate
  {
    fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; compare: lhs", to_operand(lhs_location));
    fmt.sbprintln(&ctx.output, "  mov rsi, [rdi] ; compare: lhs");
    fmt.sbprintln(&ctx.output, "  mov al, 0 ; compare: rhs");
  }
  else
  {
    fmt.sbprintfln(&ctx.output, "  lea rsi, %s ; compare: lhs", to_operand(lhs_location));
    fmt.sbprintln(&ctx.output, "  mov rsi, [rsi] ; compare: lhs");
    fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; compare: rhs", to_operand(rhs_location));
    fmt.sbprintln(&ctx.output, "  mov rdi, [rdi] ; compare: rhs");
  }

  fmt.sbprintfln(&ctx.output, "  mov rcx, %s ; compare: count", to_operand(lhs_length_location));
  fmt.sbprintfln(&ctx.output, "  repe %s ; compare", nil_compare ? "scasb" : "cmpsb");

  fmt.sbprintfln(&ctx.output, ".slice_cmp_%i_set:", slice_cmp_index)

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

generate_expression_bool :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, register_num: int) -> location
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

generate_expression_float :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, register_num: int) -> location
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

generate_expression_atomic_integer :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, register_num: int) -> location
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

generate_expression_integer :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, register_num: int) -> location
{
  _, signed_integer_type := slice.linear_search(type_checking.signed_integer_types, operand_type_node.value)
  prefix := signed_integer_type ? "i" : ""
  less := signed_integer_type ? "l" : "b"
  greater := signed_integer_type ? "g" : "a"

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
      fmt.sbprintfln(&ctx.output, "  set%s %s ; less than", less, to_operand(result_location))
    case .greater_than:
      fmt.sbprintfln(&ctx.output, "  set%s %s ; greater than", greater, to_operand(result_location))
    case .less_than_or_equal:
      fmt.sbprintfln(&ctx.output, "  set%se %s ; less than or equal", less, to_operand(result_location))
    case .greater_than_or_equal:
      fmt.sbprintfln(&ctx.output, "  set%se %s ; greater than or equal", greater, to_operand(result_location))
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
  case .bitwise_or:
    result_location = copy_to_register(ctx, lhs_location, register_num, result_type_node)
    fmt.sbprintfln(&ctx.output, "  or %s, %s ; or", to_operand(result_location), to_operand(rhs_location))
  case .multiply:
    if signed_integer_type
    {
      result_location = copy_to_register(ctx, lhs_location, register_num, result_type_node)
      fmt.sbprintfln(&ctx.output, "  imul %s, %s ; multiply", to_operand(result_location), to_operand(rhs_location))
    }
    else
    {
      // TODO more testing!
      rhs_non_immediate_location := copy_to_non_immediate(ctx, rhs_location, register_num + 1, result_type_node)
      fmt.sbprintfln(&ctx.output, "  mov %s, %s ; multiply: lhs", to_operand(register("ax", result_type_node)), to_operand(lhs_location))
      fmt.sbprintfln(&ctx.output, "  %smul %s %s ; multiply", prefix, to_operation_size(to_byte_size(result_type_node)), to_operand(rhs_non_immediate_location))
      fmt.sbprintfln(&ctx.output, "  mov %s, %s ; multiply: assign result", to_operand(result_location), to_operand(register("ax", result_type_node)))
    }
  case .divide, .modulo:
    // dividend / divisor

    operation_name := "divide"
    output_register_name := "ax"
    if node.type == .modulo
    {
      operation_name = "modulo"
      output_register_name = "dx"
    }

    rhs_non_immediate_location := copy_to_non_immediate(ctx, rhs_location, register_num + 1, result_type_node)
    output_register := register(output_register_name, result_type_node)
    fmt.sbprintfln(&ctx.output, "  mov %s, 0 ; %s: assign zero to dividend high part", to_operand(register("dx", result_type_node)), operation_name)
    fmt.sbprintfln(&ctx.output, "  mov %s, %s ; %s: assign lhs to dividend low part", to_operand(register("ax", result_type_node)), to_operand(lhs_location), operation_name)
    fmt.sbprintfln(&ctx.output, "  %sdiv %s %s ; %s", prefix, to_operation_size(to_byte_size(result_type_node)), to_operand(rhs_non_immediate_location), operation_name)
    fmt.sbprintfln(&ctx.output, "  mov %s, %s ; %s: assign result", to_operand(result_location), to_operand(output_register), operation_name)
  case .bitwise_and:
    result_location = copy_to_register(ctx, lhs_location, register_num, result_type_node)
    fmt.sbprintfln(&ctx.output, "  and %s, %s ; and", to_operand(result_location), to_operand(rhs_location))
  case:
    assert(false, "Failed to generate expression")
  }

  return result_location
}

generate_expression_any :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, operand_type_node: ^ast.node, result_type_node: ^ast.node, register_num: int) -> location
{
  result_location := register(register_num, result_type_node)

  nil_compare := lhs_location.type == .immediate || rhs_location.type == .immediate

  if lhs_location.type == .immediate
  {
    fmt.sbprintln(&ctx.output, "  mov al, 0 ; compare: lhs");
    fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; compare: rhs", to_operand(rhs_location));
  }
  else if rhs_location.type == .immediate
  {
    fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; compare: lhs", to_operand(lhs_location));
    fmt.sbprintln(&ctx.output, "  mov al, 0 ; compare: rhs");
  }
  else
  {
    fmt.sbprintfln(&ctx.output, "  lea rsi, %s ; compare: lhs", to_operand(lhs_location));
    fmt.sbprintfln(&ctx.output, "  lea rdi, %s ; compare: rhs", to_operand(rhs_location));
  }

  fmt.sbprintfln(&ctx.output, "  mov rcx, %i ; compare: count", to_byte_size(operand_type_node));
  fmt.sbprintfln(&ctx.output, "  repe %s ; compare", nil_compare ? "scasb" : "cmpsb");

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
