package generation

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"

import "../ast"
import "../type_checking"

generate_assignment :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context)
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

  fmt.fprintln(file, "  ; assignment")

  allocator := ast.get_allocator(lhs_node)

  if lhs_node.type == .identifier && !ast.is_member(lhs_node) && !(lhs_node.value in ctx.stack_variable_offsets)
  {
    if allocator == "heap"
    {
      allocate_heap(file, to_byte_size(&lhs_type_node.children[0]), ctx)
    }
    else if allocator == "stack"
    {
      allocate_stack(file, to_byte_size(lhs_type_node), ctx)
    }
    else
    {
      assert(false, "Failed to generate assignment")
    }

    ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size
  }

  lhs_location := generate_primary(file, lhs_node, ctx, 0, false)

  if len(node.children) == 1
  {
    if allocator == "stack"
    {
      nilify(file, lhs_location, lhs_type_node)
    }
  }
  else
  {
    operator_node := &node.children[1]
    rhs_node := &node.children[2]

    rhs_location := generate_expression(file, rhs_node, ctx, 1)

    if operator_node.type == .assign
    {
      copy(file, rhs_location, lhs_location, lhs_type_node)
    }
    else
    {
      _, float_type := slice.linear_search(type_checking.float_types, lhs_type_node.value)
      _, atomic_integer_type := slice.linear_search(type_checking.atomic_integer_types, lhs_type_node.value)
      _, signed_integer_type := slice.linear_search(type_checking.signed_integer_types, lhs_type_node.value)

      if float_type
      {
        generate_assignment_float(file, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
      }
      else if lhs_type_node.value == "[array]" || lhs_type_node.value == "[slice]"
      {
        generate_assignment_float_array(file, operator_node, lhs_location, rhs_location, lhs_type_node, ctx, 2)
      }
      else if atomic_integer_type
      {
        generate_assignment_atomic_integer(file, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
      }
      else if signed_integer_type
      {
        generate_assignment_signed_integer(file, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
      }
      else
      {
        assert(false, "Failed to generate assignment")
      }
    }
  }
}

generate_assignment_float :: proc(file: os.Handle, node: ^ast.node, lhs_location: location, rhs_location: location, type_node: ^ast.node, register_num: int)
{
  precision := to_precision_size(to_byte_size(type_node))
  result_location := copy_to_register(file, lhs_location, register_num, type_node)

  #partial switch node.type
  {
  case .add_assign:
    fmt.fprintfln(file, "  adds%s %s, %s ; add assign", precision, to_operand(result_location), to_operand(rhs_location))
  case .subtract_assign:
    fmt.fprintfln(file, "  subs%s %s, %s ; subtract assign", precision, to_operand(result_location), to_operand(rhs_location))
  case .multiply_assign:
    fmt.fprintfln(file, "  muls%s %s, %s ; multiply assign", precision, to_operand(result_location), to_operand(rhs_location))
  case .divide_assign:
    fmt.fprintfln(file, "  divs%s %s, %s ; divide assign", precision, to_operand(result_location), to_operand(rhs_location))
  case:
    assert(false, "Failed to generate assignment")
  }

  copy(file, result_location, lhs_location, type_node)
}

generate_assignment_float_array :: proc(file: os.Handle, node: ^ast.node, lhs_location: location, rhs_location: location, type_node: ^ast.node, ctx: ^gen_context, register_num: int)
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
      fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, to_operand(lhs_register_location), to_operand(lhs_location))
      fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, to_operand(rhs_register_location), to_operand(rhs_location))

      #partial switch node.type
      {
      case .add_assign:
        fmt.fprintfln(file, "  addp%s %s, %s ; add assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
      case .subtract_assign:
        fmt.fprintfln(file, "  subp%s %s, %s ; subtract assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
      case .multiply_assign:
        fmt.fprintfln(file, "  mulp%s %s, %s ; multiply assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
      case .divide_assign:
        fmt.fprintfln(file, "  divp%s %s, %s ; divide assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
      case:
        assert(false, "Failed to generate assignment")
      }

      if length == 4
      {
        fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, to_operand(lhs_location), to_operand(lhs_register_location))
      }
      else
      {
        limit := lhs_location
        limit.offset += (length - 1) * element_size

        for lhs_location.offset <= limit.offset
        {
          fmt.fprintfln(file, "  movs%s %s, %s ; copy", precision, to_operand(lhs_location), to_operand(lhs_register_location))
          if lhs_location.offset < limit.offset
          {
            fmt.fprintfln(file, "  shufp%s %s, %s, 0x39 ; shuffle", precision, to_operand(lhs_register_location), to_operand(lhs_register_location))
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
    fmt.fprintfln(file, "  lea %s, %s ; reference", to_operand(lhs_address_location), to_operand(lhs_location))
  }
  else
  {
    copy(file, lhs_location, lhs_address_location, &unknown_reference_type_node)
  }
  lhs_location = memory(to_operand(lhs_address_location), 0)

  rhs_address_location := register(register_num + 1, &unknown_reference_type_node)
  if type_node.value == "[array]"
  {
    fmt.fprintfln(file, "  lea %s, %s ; reference", to_operand(rhs_address_location), to_operand(rhs_location))
  }
  else
  {
    copy(file, rhs_location, rhs_address_location, &unknown_reference_type_node)
  }
  rhs_location = memory(to_operand(rhs_address_location), 0)

  limit_location := register(register_num + 2, &index_type_node)
  copy(file, length_location, limit_location, &index_type_node)
  fmt.fprintfln(file, "  sub %s, 4 ; subtract", to_operand(limit_location))
  fmt.fprintfln(file, "  imul %s, %s ; multiply", to_operand(limit_location), to_operand(immediate(element_size)))
  fmt.fprintfln(file, "  add %s, %s ; add", to_operand(limit_location), to_operand(lhs_address_location))

  fmt.fprintfln(file, "vector_assign_multi_loop_%i:", vector_assign_index)
  fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, to_operand(lhs_register_location), to_operand(lhs_location))
  fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, to_operand(rhs_register_location), to_operand(rhs_location))

  #partial switch node.type
  {
  case .add_assign:
    fmt.fprintfln(file, "  addp%s %s, %s ; add assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
  case .subtract_assign:
    fmt.fprintfln(file, "  subp%s %s, %s ; subtract assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
  case .multiply_assign:
    fmt.fprintfln(file, "  mulp%s %s, %s ; multiply assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
  case .divide_assign:
    fmt.fprintfln(file, "  divp%s %s, %s ; divide assign", precision, to_operand(lhs_register_location), to_operand(rhs_register_location))
  case:
    assert(false, "Failed to generate assignment")
  }

  fmt.fprintfln(file, "  cmp %s, %s ; compare", to_operand(lhs_address_location), to_operand(limit_location))
  fmt.fprintfln(file, "  jg vector_assign_single_%i ; skip to single loop", vector_assign_index)

  fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, to_operand(lhs_location), to_operand(lhs_register_location))
  fmt.fprintfln(file, "  add %s, %s ; add", to_operand(lhs_address_location), to_operand(immediate(4 * element_size)))
  fmt.fprintfln(file, "  add %s, %s ; add", to_operand(rhs_address_location), to_operand(immediate(4 * element_size)))
  fmt.fprintfln(file, "  jmp vector_assign_multi_loop_%i", vector_assign_index)

  fmt.fprintfln(file, "vector_assign_single_%i:", vector_assign_index)
  fmt.fprintfln(file, "  add %s, %s ; add", to_operand(limit_location), to_operand(immediate(3 * element_size)))

  fmt.fprintfln(file, "vector_assign_single_loop_%i:", vector_assign_index)
  fmt.fprintfln(file, "  cmp %s, %s ; compare", to_operand(lhs_address_location), to_operand(limit_location))
  fmt.fprintfln(file, "  jg vector_assign_single_end_%i ; skip to end", vector_assign_index)

  fmt.fprintfln(file, "  movs%s %s, %s ; copy", precision, to_operand(lhs_location), to_operand(lhs_register_location))

  fmt.fprintfln(file, "  cmp %s, %s ; compare", to_operand(lhs_address_location), to_operand(limit_location))
  fmt.fprintfln(file, "  jge vector_assign_single_inc_%i ; skip shuffle", vector_assign_index)
  fmt.fprintfln(file, "  shufp%s %s, %s, 0x39 ; shuffle", precision, to_operand(lhs_register_location), to_operand(lhs_register_location))

  fmt.fprintfln(file, "vector_assign_single_inc_%i:", vector_assign_index)
  fmt.fprintfln(file, "  add %s, %s ; add", to_operand(lhs_address_location), to_operand(immediate(element_size)))

  fmt.fprintfln(file, "  jmp vector_assign_single_loop_%i", vector_assign_index)

  fmt.fprintfln(file, "vector_assign_single_end_%i:", vector_assign_index)
}

generate_assignment_atomic_integer :: proc(file: os.Handle, node: ^ast.node, lhs_location: location, rhs_location: location, type_node: ^ast.node, register_num: int)
{
  rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, type_node)

  #partial switch node.type
  {
  case .add_assign:
    fmt.fprintfln(file, "  lock xadd %s, %s ; atomic add assign", to_operand(lhs_location), to_operand(rhs_register_location))
  case .subtract_assign:
    fmt.fprintfln(file, "  neg %s ; negate", to_operand(rhs_register_location))
    fmt.fprintfln(file, "  lock xadd %s, %s ; atomic add assign", to_operand(lhs_location), to_operand(rhs_register_location))
  case:
    assert(false, "Failed to generate assignment")
  }
}

generate_assignment_signed_integer :: proc(file: os.Handle, node: ^ast.node, lhs_location: location, rhs_location: location, type_node: ^ast.node, register_num: int)
{
  #partial switch node.type
  {
  case .add_assign:
    rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, type_node)
    fmt.fprintfln(file, "  add %s, %s ; add assign", to_operand(lhs_location), to_operand(rhs_register_location))
  case .subtract_assign:
    rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, type_node)
    fmt.fprintfln(file, "  sub %s, %s ; subtract assign", to_operand(lhs_location), to_operand(rhs_register_location))
  case .multiply_assign:
    result_location := copy_to_register(file, lhs_location, register_num, type_node)
    rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, type_node)
    fmt.fprintfln(file, "  imul %s, %s ; multiply assign", to_operand(result_location), to_operand(rhs_register_location))
    copy(file, result_location, lhs_location, type_node)
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

    rhs_register_location := copy_to_non_immediate(file, rhs_location, register_num + 1, type_node)
    output_register := register(output_register_name, type_node)
    fmt.fprintfln(file, "  mov %s, 0 ; %s: assign zero to dividend high part", to_operand(register("dx", type_node)), operation_name)
    fmt.fprintfln(file, "  mov %s, %s ; %s: assign lhs to dividend low part", to_operand(register("ax", type_node)), to_operand(lhs_location), operation_name)
    fmt.fprintfln(file, "  idiv %s %s ; %s", to_operation_size(to_byte_size(type_node)), to_operand(rhs_register_location), operation_name)
    fmt.fprintfln(file, "  mov %s, %s ; %s: assign result", to_operand(lhs_location), to_operand(output_register), operation_name)
  case:
    assert(false, "Failed to generate assignment")
  }
}
