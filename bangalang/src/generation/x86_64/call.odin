package x86_64

import "core:fmt"

import "../../ast"
import ".."

extern_param_registers_named: []string = { "di", "si", "dx", "cx" }
extern_param_registers_numbered: []int = { -3, -2 }
syscall_param_registers_named: []string = { "ax", "di", "si", "dx" }
syscall_param_registers_numbered: []int = { -1, -3, -2 }

generate_call :: proc(ctx: ^generation.gen_context, node: ^ast.node, register_num: int, child_location: location, deallocate_return: bool) -> location
{
  procedure_node := &node.children[0]
  if ast.is_type(procedure_node)
  {
    return generate_conversion_call(ctx, node, register_num)
  }

  procedure_type_node := ast.get_type(procedure_node)

  params_type_node := procedure_type_node.children[0]
  return_type_node := len(procedure_type_node.children) == 2 ? &procedure_type_node.children[1] : nil

  call_stack_size := 0
  return_only_call_stack_size := 0
  if procedure_type_node.directive != "#extern"
  {
    for &param_node in params_type_node.children
    {
      call_stack_size += to_byte_size(ast.get_type(&param_node))
    }
    if return_type_node != nil
    {
      call_stack_size += to_byte_size(return_type_node)
      return_only_call_stack_size += to_byte_size(return_type_node)
    }
  }

  misalignment := (ctx.stack_size + call_stack_size) % 16
  if misalignment != 0
  {
    misalignment = 16 - misalignment
    call_stack_size += misalignment
    return_only_call_stack_size += misalignment
  }

  allocate_stack(ctx, call_stack_size)

  if procedure_type_node.directive == "#extern"
  {
    for &param_node_from_type, param_index in params_type_node.children
    {
      param_node := &node.children[param_index + 1]
      param_type_node := ast.get_type(&param_node_from_type)

      param_registers_named := procedure_node.value == "syscall" ? syscall_param_registers_named : extern_param_registers_named
      param_registers_numbered := procedure_node.value == "syscall" ? syscall_param_registers_numbered : extern_param_registers_numbered

      expression_location := generate_expression(ctx, param_node, register_num)

      param_location: location
      if param_index < len(param_registers_named)
      {
        param_location = register(param_registers_named[param_index], param_type_node)
      }
      else if param_index < len(param_registers_named) + len(param_registers_numbered)
      {
        param_location = register(param_registers_numbered[param_index - len(param_registers_named)], param_type_node)
      }
      else
      {
        assert(false, "Pass by stack not yet supported when calling c")
      }

      copy(ctx, expression_location, param_location, param_type_node)
    }
  }
  else
  {
    offset := call_stack_size - return_only_call_stack_size
    for &param_node_from_type, param_index in params_type_node.children
    {
      param_node := &node.children[param_index + 1]
      param_type_node := ast.get_type(&param_node_from_type)

      offset -= to_byte_size(param_type_node)

      expression_location := generate_expression(ctx, param_node, register_num)
      copy(ctx, expression_location, memory("rsp", offset), param_type_node)
    }

    if !deallocate_return
    {
      call_stack_size -= return_only_call_stack_size
    }
  }

  if procedure_node.value == "syscall"
  {
    fmt.sbprintln(&ctx.output, "  syscall ; call kernal")
  }
  else if child_location.type == .immediate
  {
    fmt.sbprintfln(&ctx.output, "  call %s ; call procedure", to_operand(child_location))
  }
  else
  {
    fmt.sbprintfln(&ctx.output, "  call %s ; call procedure (%s)", to_operand(child_location), procedure_node.value)
  }

  deallocate_stack(ctx, call_stack_size)

  if return_type_node == nil
  {
    return {}
  }

  if procedure_type_node.directive == "#extern"
  {
    return register("ax", return_type_node)
  }
  else
  {
    return copy_stack_address(ctx, 0, register_num)
  }
}

generate_conversion_call :: proc(ctx: ^generation.gen_context, node: ^ast.node, register_num: int) -> location
{
  procedure_node := &node.children[0]
  procedure_type_node := ast.get_type(procedure_node)

  param_type_node := &procedure_type_node.children[0].children[0].children[0]
  return_type_node := &procedure_type_node.children[1]

  param_location := generate_expression(ctx, &node.children[1], register_num)

  return convert(ctx, param_location, register_num, param_type_node, return_type_node)
}
