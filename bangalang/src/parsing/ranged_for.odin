package parsing

import "core:slice"

import "../ast"
import "../src"
import "../tokens"

parse_ranged_for :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .ranged_for_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  for_token, for_ok := tokens.next_token(stream, .keyword, "for")
  if !for_ok
  {
    stream.error = src.to_position_message(for_token.src_position, "for loop must begin with 'for'")
    return {}, false
  }

  element_token, element_ok := tokens.next_token(stream, .identifier)
  if !element_ok
  {
    stream.error = src.to_position_message(element_token.src_position, "'for' must be followed by an identifier in a ranged for loop")
    return {}, false
  }

  element_node := ast.to_node(element_token)
  append(&node.children, element_node)

  in_token, in_ok := tokens.next_token(stream, .keyword, "in")
  if !element_ok
  {
    stream.error = src.to_position_message(element_token.src_position, "element identifier in a ranged for loop must be followed by 'in'")
    return {}, false
  }

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
