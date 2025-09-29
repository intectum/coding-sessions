package x86_64

import "core:fmt"

import "../../ast"
import ".."

generate_return :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  fmt.sbprintln(&ctx.output, "  ; return")

  if !(ctx.procedure_name in ctx.program.modules)
  {
    if len(node.children) > 0
    {
      expression_node := &node.children[0]
      expression_type_node := ast.get_type(expression_node)

      expression_location := generate_expression(ctx, expression_node)

      variable_position := ctx.stack_size - ctx.stack_variable_offsets["[return]"]
      return_location := memory("rsp", variable_position)

      copy(ctx, expression_location, return_location, expression_type_node)
    }

    stack_size := ctx.stack_size

    // Account for the instruction pointer pushed to the stack by 'call'
    ctx.stack_size -= address_size
    deallocate_stack(ctx, ctx.stack_size)
    fmt.sbprintln(&ctx.output, "  ret ; return")

    ctx.stack_size = stack_size
  }
  else
  {
    expression_node := &node.children[0]
    expression_type_node := ast.get_type(expression_node)

    expression_location := generate_expression(ctx, expression_node)

    syscall_num_location := register("ax", expression_type_node)
    exit_code_location := register("di", expression_type_node)

    copy(ctx, immediate(60), syscall_num_location, expression_type_node)
    copy(ctx, expression_location, exit_code_location, expression_type_node)

    fmt.sbprintln(&ctx.output, "  syscall ; call kernel")
  }
}
