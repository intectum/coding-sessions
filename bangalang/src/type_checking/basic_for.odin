package type_checking

import "core:slice"

import "../ast"

type_check_basic_for :: proc(ctx: ^type_checking_context, node: ^ast.node) -> bool
{
  for_ctx := copy_context(ctx)
  for_ctx.within_for = true

  flow_node := node.children[0]
  scope_node := node.children[1]

  pre_node := flow_node.children[0].type == .group ? flow_node.children[0] : nil
  expression_node_index := pre_node == nil ? 0 : 1
  expression_node := flow_node.children[expression_node_index]
  post_node := len(flow_node.children) > expression_node_index + 1 ? flow_node.children[expression_node_index + 1] : nil

  if pre_node != nil do type_check_statements(&for_ctx, pre_node.children[:]) or_return

  type_check_rhs_expression(&for_ctx, expression_node, for_ctx.program.identifiers["bool"]) or_return

  if post_node != nil do type_check_statements(&for_ctx, post_node.children[:]) or_return

  type_check_scope(&for_ctx, scope_node) or_return

  ctx.next_index = for_ctx.next_index

  return true
}
