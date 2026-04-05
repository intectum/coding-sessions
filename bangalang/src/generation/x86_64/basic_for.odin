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

  flow_node := node.children[0]
  scope_node := node.children[1]

  pre_node := flow_node.children[0].type == .group ? flow_node.children[0] : nil
  expression_node_index := pre_node == nil ? 0 : 1
  expression_node := flow_node.children[expression_node_index]
  post_node := len(flow_node.children) > expression_node_index + 1 ? flow_node.children[expression_node_index + 1] : nil

  if pre_node != nil do generate_statements(&for_ctx, pre_node.children[:])

  fmt.sbprintfln(&for_ctx.output, ".for_%i:", for_ctx.for_index)

  expression_type_node := expression_node.data_type
  expression_operation_size := to_operation_size(to_byte_size(expression_type_node))

  expression_location := generate_expression(&for_ctx, expression_node)
  expression_location = copy_to_non_immediate(&for_ctx, expression_location, 0, expression_type_node)
  fmt.sbprintfln(&for_ctx.output, "  cmp %s %s, 0 ; test expression", expression_operation_size, to_operand(expression_location))
  fmt.sbprintfln(&for_ctx.output, "  je .for_%i_end ; skip for scope when false/zero", for_ctx.for_index)

  generate_scope(&for_ctx, scope_node)

  fmt.sbprintfln(&for_ctx.output, ".for_%i_continue:", for_ctx.for_index)

  if post_node != nil do generate_statements(&for_ctx, post_node.children[:])

  fmt.sbprintfln(&for_ctx.output, "  jmp .for_%i ; back to top", for_ctx.for_index)
  fmt.sbprintfln(&for_ctx.output, ".for_%i_end:", for_ctx.for_index)

  deallocate_stack(&for_ctx, for_ctx.stack_size - ctx.stack_size)
  ctx.next_index = for_ctx.next_index
  ctx.output = for_ctx.output
}
