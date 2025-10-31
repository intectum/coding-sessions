package x86_64

import "core:fmt"

import "../../ast"
import "../../program"
import ".."

generate_procedure :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  lhs_node := &node.children[0]
  lhs_type_node := ast.get_type(lhs_node)

  offset := 0
  params_type_node := lhs_type_node.children[0]
  for param_index := len(params_type_node.children) - 1; param_index >= 0; param_index -= 1
  {
    param_node := &params_type_node.children[param_index]
    param_lhs_node := &param_node.children[0]

    ctx.stack_variable_offsets[param_lhs_node.value] = offset
    offset -= to_byte_size(ast.get_type(param_lhs_node))
  }

  ctx.stack_variable_offsets["[return]"] = offset

  fmt.sbprintfln(&ctx.output, "%s:", program.get_qualified_name(ctx.path[:]))

  // Account for the instruction pointer pushed to the stack by 'call'
  ctx.stack_size += address_size

  rhs_node := &node.children[2]
  generate_statement(ctx, rhs_node)

  // Account for the instruction pointer pushed to the stack by 'call'
  ctx.stack_size -= address_size
  deallocate_stack(ctx, ctx.stack_size)
  fmt.sbprintln(&ctx.output, "  ret ; default return")
}
