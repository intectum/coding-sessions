package x86_64

import "core:fmt"
import "core:slice"
import "core:strconv"

import "../../ast"
import "../../type_checking"
import ".."

generate_assignment :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  lhs_node := &node.children[0]
  if ast.is_type(lhs_node)
  {
    return
  }

  lhs_type_node := ast.get_type(lhs_node)
  if lhs_type_node.value == "[module]"
  {
    return
  }

  fmt.sbprintln(&ctx.output, "  ; assignment")

  allocator := ast.get_allocator(lhs_node)

  if lhs_node.type == .identifier && !ast.is_member(lhs_node) && !(lhs_node.value in ctx.stack_variable_offsets)
  {
    if allocator == "heap" || allocator == "vram"
    {
      allocate_stack(ctx, to_byte_size(lhs_type_node))

      rhs_node := &node.children[2]
      param_node := &rhs_node.children[1]

      // TODO a bit hacky, adds the size info to the allocator call
      buf: [8]byte
      param_node.value = strconv.itoa(buf[:], to_byte_size(&lhs_type_node.children[0]))
    }
    else if allocator == "stack"
    {
      allocate_stack(ctx, to_byte_size(lhs_type_node))
    }
    else if allocator == "static"
    {
      static_var_found := false
      for static_var_node in ctx.program.static_vars
      {
        static_var_lhs_node := &static_var_node.children[0]
        if static_var_lhs_node.value == lhs_node.value
        {
          static_var_found = true
          break
        }
      }

      if !static_var_found
      {
        append(&ctx.program.static_vars, node^)
      }
    }
    else
    {
      assert(false, "Failed to generate assignment")
    }

    ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size
  }

  lhs_location := generate_primary(ctx, lhs_node, 0, false)

  if len(node.children) == 1
  {
    if allocator == "stack" || allocator == "static"
    {
      nilify(ctx, lhs_location, lhs_type_node)
    }
  }
  else
  {
    operator_node := &node.children[1]
    rhs_node := &node.children[2]

    rhs_location := generate_expression(ctx, rhs_node, 1)

    if operator_node.type == .assign
    {
      copy(ctx, rhs_location, lhs_location, lhs_type_node)
    }
    else
    {
      _, float_type := slice.linear_search(type_checking.float_types, lhs_type_node.value)
      _, atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, lhs_type_node.value)
      _, signed_integer_type := slice.linear_search(type_checking.signed_integer_types, lhs_type_node.value)

      if float_type
      {
        generate_assignment_float(ctx, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
      }
      else if lhs_type_node.value == "[array]" || lhs_type_node.value == "[slice]"
      {
        generate_assignment_float_array(ctx, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
      }
      else if atomic_integer_type
      {
        generate_assignment_atomic_integer(ctx, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
      }
      else if signed_integer_type
      {
        generate_assignment_signed_integer(ctx, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
      }
      else
      {
        assert(false, "Failed to generate assignment")
      }
    }
  }
}

generate_assignment_float :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, type_node: ^ast.node, register_num: int)
{
  precision := to_precision_size(to_byte_size(type_node))
  result_location := copy_to_register(ctx, lhs_location, register_num, type_node)

  #partial switch node.type
  {
  case .add_assign:
    fmt.sbprintfln(&ctx.output, "  adds%s %s, %s ; add assign", precision, to_operand(result_location), to_operand(rhs_location))
  case .subtract_assign:
    fmt.sbprintfln(&ctx.output, "  subs%s %s, %s ; subtract assign", precision, to_operand(result_location), to_operand(rhs_location))
  case .multiply_assign:
    fmt.sbprintfln(&ctx.output, "  muls%s %s, %s ; multiply assign", precision, to_operand(result_location), to_operand(rhs_location))
  case .divide_assign:
    fmt.sbprintfln(&ctx.output, "  divs%s %s, %s ; divide assign", precision, to_operand(result_location), to_operand(rhs_location))
  case:
    assert(false, "Failed to generate assignment")
  }

  copy(ctx, result_location, lhs_location, type_node)
}

generate_assignment_float_array :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, type_node: ^ast.node, register_num: int)
{
  lhs_location := lhs_location
  rhs_location := rhs_location

  element_type_node := &type_node.children[0]
  element_size := to_byte_size(element_type_node)
  precision := to_precision_size(element_size)

  lhs_register_location := register(register_num, element_type_node)
  rhs_register_location := register(register_num + 1, element_type_node)

  length_location := get_length_location(type_node, lhs_location)
  if length_location.type == .immediate
  {
    length := strconv.atoi(length_location.value)
    if length <= 4
    {
      fmt.sbprintfln(&ctx.output, "  movup%s %s, %s ; copy", precision, to_operand(lhs_register_location), to_operand(lhs_location))
      fmt.sbprintfln(&ctx.output, "  movup%s %s, %s ; copy", precision, to_operand(rhs_register_location), to_operand(rhs_location))

      #partial switch node.type
      {
      case .add_assign:
        fmt.sbprintfln(&ctx.output, "  addp%s %s, %s ; add assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
      case .subtract_assign:
        fmt.sbprintfln(&ctx.output, "  subp%s %s, %s ; subtract assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
      case .multiply_assign:
        fmt.sbprintfln(&ctx.output, "  mulp%s %s, %s ; multiply assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
      case .divide_assign:
        fmt.sbprintfln(&ctx.output, "  divp%s %s, %s ; divide assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
      case:
        assert(false, "Failed to generate assignment")
      }

      if length == 4
      {
        fmt.sbprintfln(&ctx.output, "  movup%s %s, %s ; copy", precision, to_operand(lhs_location), to_operand(lhs_register_location))
      }
      else
      {
        limit := lhs_location
        limit.offset += (length - 1) * element_size

        for lhs_location.offset <= limit.offset
        {
          fmt.sbprintfln(&ctx.output, "  movs%s %s, %s ; copy", precision, to_operand(lhs_location), to_operand(lhs_register_location))
          if lhs_location.offset < limit.offset
          {
            fmt.sbprintfln(&ctx.output, "  shufp%s %s, %s, 0x39 ; shuffle", precision, to_operand(lhs_register_location), to_operand(lhs_register_location))
          }

          lhs_location.offset += element_size
        }
      }

      return
    }
  }

  vector_assign_index := ctx.label_index
  ctx.label_index += 1

  lhs_address_location := register(register_num, &unknown_reference_type_node)
  if type_node.value == "[array]"
  {
    fmt.sbprintfln(&ctx.output, "  lea %s, %s ; reference", to_operand(lhs_address_location), to_operand(lhs_location))
  }
  else
  {
    copy(ctx, lhs_location, lhs_address_location, &unknown_reference_type_node)
  }
  lhs_location = memory(to_operand(lhs_address_location), 0)

  rhs_address_location := register(register_num + 1, &unknown_reference_type_node)
  if type_node.value == "[array]"
  {
    fmt.sbprintfln(&ctx.output, "  lea %s, %s ; reference", to_operand(rhs_address_location), to_operand(rhs_location))
  }
  else
  {
    copy(ctx, rhs_location, rhs_address_location, &unknown_reference_type_node)
  }
  rhs_location = memory(to_operand(rhs_address_location), 0)

  limit_location := register(register_num + 2, &index_type_node)
  copy(ctx, length_location, limit_location, &index_type_node)
  fmt.sbprintfln(&ctx.output, "  sub %s, 4 ; subtract", to_operand(limit_location))
  fmt.sbprintfln(&ctx.output, "  imul %s, %s ; multiply", to_operand(limit_location), to_operand(immediate(element_size)))
  fmt.sbprintfln(&ctx.output, "  add %s, %s ; add", to_operand(limit_location), to_operand(lhs_address_location))

  fmt.sbprintfln(&ctx.output, "vector_assign_multi_loop_%i:", vector_assign_index)
  fmt.sbprintfln(&ctx.output, "  movup%s %s, %s ; copy", precision, to_operand(lhs_register_location), to_operand(lhs_location))
  fmt.sbprintfln(&ctx.output, "  movup%s %s, %s ; copy", precision, to_operand(rhs_register_location), to_operand(rhs_location))

  #partial switch node.type
  {
  case .add_assign:
    fmt.sbprintfln(&ctx.output, "  addp%s %s, %s ; add assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
  case .subtract_assign:
    fmt.sbprintfln(&ctx.output, "  subp%s %s, %s ; subtract assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
  case .multiply_assign:
    fmt.sbprintfln(&ctx.output, "  mulp%s %s, %s ; multiply assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
  case .divide_assign:
    fmt.sbprintfln(&ctx.output, "  divp%s %s, %s ; divide assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
  case:
    assert(false, "Failed to generate assignment")
  }

  fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare", to_operand(lhs_address_location), to_operand(limit_location))
  fmt.sbprintfln(&ctx.output, "  jg vector_assign_single_%i ; skip to single loop", vector_assign_index)

  fmt.sbprintfln(&ctx.output, "  movup%s %s, %s ; copy", precision, to_operand(lhs_location), to_operand(lhs_register_location))
  fmt.sbprintfln(&ctx.output, "  add %s, %s ; add", to_operand(lhs_address_location), to_operand(immediate(4 * element_size)))
  fmt.sbprintfln(&ctx.output, "  add %s, %s ; add", to_operand(rhs_address_location), to_operand(immediate(4 * element_size)))
  fmt.sbprintfln(&ctx.output, "  jmp vector_assign_multi_loop_%i", vector_assign_index)

  fmt.sbprintfln(&ctx.output, "vector_assign_single_%i:", vector_assign_index)
  fmt.sbprintfln(&ctx.output, "  add %s, %s ; add", to_operand(limit_location), to_operand(immediate(3 * element_size)))

  fmt.sbprintfln(&ctx.output, "vector_assign_single_loop_%i:", vector_assign_index)
  fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare", to_operand(lhs_address_location), to_operand(limit_location))
  fmt.sbprintfln(&ctx.output, "  jg vector_assign_single_end_%i ; skip to end", vector_assign_index)

  fmt.sbprintfln(&ctx.output, "  movs%s %s, %s ; copy", precision, to_operand(lhs_location), to_operand(lhs_register_location))

  fmt.sbprintfln(&ctx.output, "  cmp %s, %s ; compare", to_operand(lhs_address_location), to_operand(limit_location))
  fmt.sbprintfln(&ctx.output, "  jge vector_assign_single_inc_%i ; skip shuffle", vector_assign_index)
  fmt.sbprintfln(&ctx.output, "  shufp%s %s, %s, 0x39 ; shuffle", precision, to_operand(lhs_register_location), to_operand(lhs_register_location))

  fmt.sbprintfln(&ctx.output, "vector_assign_single_inc_%i:", vector_assign_index)
  fmt.sbprintfln(&ctx.output, "  add %s, %s ; add", to_operand(lhs_address_location), to_operand(immediate(element_size)))

  fmt.sbprintfln(&ctx.output, "  jmp vector_assign_single_loop_%i", vector_assign_index)

  fmt.sbprintfln(&ctx.output, "vector_assign_single_end_%i:", vector_assign_index)
}

generate_assignment_atomic_integer :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, type_node: ^ast.node, register_num: int)
{
  rhs_register_location := copy_to_register(ctx, rhs_location, register_num + 1, type_node)

  #partial switch node.type
  {
  case .add_assign:
    fmt.sbprintfln(&ctx.output, "  lock xadd %s, %s ; atomic add assign", to_operand(lhs_location), to_operand(rhs_register_location))
  case .subtract_assign:
    fmt.sbprintfln(&ctx.output, "  neg %s ; negate", to_operand(rhs_register_location))
    fmt.sbprintfln(&ctx.output, "  lock xadd %s, %s ; atomic add assign", to_operand(lhs_location), to_operand(rhs_register_location))
  case:
    assert(false, "Failed to generate assignment")
  }
}

generate_assignment_signed_integer :: proc(ctx: ^generation.gen_context, node: ^ast.node, lhs_location: location, rhs_location: location, type_node: ^ast.node, register_num: int)
{
  #partial switch node.type
  {
  case .add_assign:
    rhs_register_location := copy_to_register(ctx, rhs_location, register_num + 1, type_node)
    fmt.sbprintfln(&ctx.output, "  add %s, %s ; add assign", to_operand(lhs_location), to_operand(rhs_register_location))
  case .subtract_assign:
    rhs_register_location := copy_to_register(ctx, rhs_location, register_num + 1, type_node)
    fmt.sbprintfln(&ctx.output, "  sub %s, %s ; subtract assign", to_operand(lhs_location), to_operand(rhs_register_location))
  case .multiply_assign:
    result_location := copy_to_register(ctx, lhs_location, register_num, type_node)
    rhs_register_location := copy_to_register(ctx, rhs_location, register_num + 1, type_node)
    fmt.sbprintfln(&ctx.output, "  imul %s, %s ; multiply assign", to_operand(result_location), to_operand(rhs_register_location))
    copy(ctx, result_location, lhs_location, type_node)
    result_location = lhs_location
  case .divide_assign, .modulo_assign:
    // dividend / divisor

    operation_name := "divide assign"
    output_register_name := "ax"
    if node.type == .modulo_assign
    {
      operation_name = "modulo assign"
      output_register_name = "dx"
    }

    rhs_register_location := copy_to_non_immediate(ctx, rhs_location, register_num + 1, type_node)
    output_register := register(output_register_name, type_node)
    fmt.sbprintfln(&ctx.output, "  mov %s, 0 ; %s: assign zero to dividend high part", to_operand(register("dx", type_node)), operation_name)
    fmt.sbprintfln(&ctx.output, "  mov %s, %s ; %s: assign lhs to dividend low part", to_operand(register("ax", type_node)), to_operand(lhs_location), operation_name)
    fmt.sbprintfln(&ctx.output, "  idiv %s %s ; %s", to_operation_size(to_byte_size(type_node)), to_operand(rhs_register_location), operation_name)
    fmt.sbprintfln(&ctx.output, "  mov %s, %s ; %s: assign result", to_operand(lhs_location), to_operand(output_register), operation_name)
  case:
    assert(false, "Failed to generate assignment")
  }
}
