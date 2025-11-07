package parsing

import "core:slice"

import "../ast"
import "../tokens"

parse_ranged_for :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .ranged_for_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  tokens.next_token(stream, .keyword, "for") or_return

  element_token := tokens.next_token(stream, .identifier) or_return
  element_node := ast.to_node(element_token)
  append(&node.children, element_node)

  tokens.next_token(stream, .keyword, "in") or_return

  start_expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, start_expression_node)

  if tokens.peek_token(stream).type == .period_period
  {
    tokens.next_token(stream, .period_period) or_return

    end_expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, end_expression_node)
  }

  scope_node := parse_scope(ctx, stream) or_return
  append(&node.children, scope_node)

  return node, true
}
