package generation

import "core:fmt"
import "core:os"

import "../ast"

generate_procedure :: proc(file: os.Handle, node: ^ast.node, ctx: ^gen_context)
{
  lhs_node := &node.children[0]
  lhs_type_node := ast.get_type(lhs_node)

  if lhs_type_node.directive == "#extern"
  {
    fmt.fprintfln(file, "extern %s", lhs_node.value)
    return
  }

  procedure_ctx := copy_gen_context(ctx, false)

  offset := 0
  params_type_node := lhs_type_node.children[0]
  for param_index := len(params_type_node.children) - 1; param_index >= 0; param_index -= 1
  {
    param_node := &params_type_node.children[param_index]

    procedure_ctx.stack_variable_offsets[param_node.value] = offset
    offset -= to_byte_size(ast.get_type(param_node))
  }

  procedure_ctx.stack_variable_offsets["[return]"] = offset

  fmt.fprintfln(file, "%s:", lhs_node.value)

  // Account for the instruction pointer pushed to the stack by 'call'
  procedure_ctx.stack_size += address_size

  rhs_node := &node.children[2]
  generate_statement(file, rhs_node, &procedure_ctx, true)

  procedure_ctx.stack_size -= address_size
  close_gen_context(file, ctx, &procedure_ctx, "procedure", false)

  fmt.fprintln(file, "  ret ; return")
}
