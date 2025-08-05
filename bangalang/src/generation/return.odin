package generation

import "core:fmt"
import "core:os"

import "../ast"

generate_return :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context)
{
  fmt.fprintln(file, "  ; return")

  if !(ctx.procedure_name in ctx.program.modules)
  {
    if len(node.children) > 0
    {
      expression_node := &node.children[0]
      expression_type_node := ast.get_type(expression_node)

      expression_location := generate_expression(file, expression_node, ctx)

      variable_position := ctx.stack_size - ctx.stack_variable_offsets["[return]"]
      return_location := memory("rsp", variable_position)

      copy(file, expression_location, return_location, expression_type_node)
    }

    fmt.fprintln(file, "  jmp .end ; skip to end")
  }
  else
  {
    expression_node := &node.children[0]
    expression_type_node := ast.get_type(expression_node)

    expression_location := generate_expression(file, expression_node, ctx)

    syscall_num_location := register("ax", expression_type_node)
    exit_code_location := register("di", expression_type_node)

    copy(file, immediate(60), syscall_num_location, expression_type_node)
    copy(file, expression_location, exit_code_location, expression_type_node)

    fmt.fprintln(file, "  syscall ; call kernel")
  }
}
