package x86_64

import "core:fmt"
import "core:slice"

import "../../ast"
import ".."

generate_basic_for :: proc(ctx: ^generation.gen_context, node: ^ast.node)
{
  for_ctx := generation.copy_context(ctx)

  for_ctx.for_index = for_ctx.next_index
  for_ctx.next_index += 1

  child_index := 0
  child_node := node.children[child_index]
  child_index += 1

  if child_node.type == .assignment_statement
  {
    generate_assignment(&for_ctx, child_node)

    child_node = node.children[child_index]
    child_index += 1
  }

  fmt.sbprintfln(&for_ctx.output, ".for_%i:", for_ctx.for_index)

  expression_type_node := child_node.data_type
  expression_operation_size := to_operation_size(to_byte_size(expression_type_node))

  expression_location := generate_expression(&for_ctx, child_node)
  expression_location = copy_to_non_immediate(&for_ctx, expression_location, 0, expression_type_node)
  fmt.sbprintfln(&for_ctx.output, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))
  fmt.sbprintfln(&for_ctx.output, "  je .for_%i_end ; skip for scope when false/zero", for_ctx.for_index)

  child_node = node.children[child_index]
  child_index += 1

  statement_node := node.children[len(node.children) - 1]
  generate_scope(&for_ctx, statement_node)

  fmt.sbprintfln(&for_ctx.output, ".for_%i_continue:", for_ctx.for_index)

  if len(node.children) > child_index
  {
    generate_assignment(&for_ctx, child_node)
  }

  fmt.sbprintfln(&for_ctx.output, "  jmp .for_%i ; back to top", for_ctx.for_index)
  fmt.sbprintfln(&for_ctx.output, ".for_%i_end:", for_ctx.for_index)

  deallocate_stack(&for_ctx, for_ctx.stack_size - ctx.stack_size)
  ctx.next_index = for_ctx.next_index
  ctx.output = for_ctx.output
}
