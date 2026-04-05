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
    stream.error = src.to_position_message(for_token.src_position, "expected 'for' keyword in ranged for loop")
    return {}, false
  }

  values_node := ast.make_node({ type = .group, value = "[values]" })

  element_token, element_ok := tokens.next_token(stream, .identifier)
  if !element_ok
  {
    stream.error = src.to_position_message(element_token.src_position, "expected element identifier in ranged for loop")
    return {}, false
  }

  element_node := ast.to_node(element_token)
  append(&values_node.children, element_node)

  if tokens.peek_token(stream).type == .comma
  {
    tokens.next_token(stream, .comma) or_return

    index_token, index_ok := tokens.next_token(stream, .identifier)
    if !index_ok
    {
      stream.error = src.to_position_message(index_token.src_position, "expected index identifier in ranged for loop")
      return {}, false
    }

    index_node := ast.to_node(index_token)
    append(&values_node.children, index_node)
  }

  append(&node.children, values_node)

  in_token, in_ok := tokens.next_token(stream, .keyword, "in")
  if !element_ok
  {
    stream.error = src.to_position_message(element_token.src_position, "expected 'in' keyword in ranged for loop")
    return {}, false
  }

  start_expression_node := parse_rhs_expression(stream) or_return

  if tokens.peek_token(stream).type == .period_period
  {
    tokens.next_token(stream, .period_period) or_return

    end_expression_node := parse_rhs_expression(stream) or_return

    range_node: = ast.make_node({ type = .range })
    append(&range_node.children, start_expression_node)
    append(&range_node.children, end_expression_node)
    append(&node.children, range_node)
  }
  else
  {
    append(&node.children, start_expression_node)
  }

  scope_node := parse_scope(ctx, stream) or_return
  append(&node.children, scope_node)

  return node, true
}
