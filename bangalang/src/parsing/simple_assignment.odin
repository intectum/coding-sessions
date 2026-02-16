package parsing

import "core:slice"

import "../ast"
import "../src"
import "../tokens"

parse_simple_assignment :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .assignment_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  lhs_token, lhs_ok := tokens.next_token(stream, .identifier)
  if !lhs_ok
  {
    stream.error = src.to_position_message(lhs_token.src_position, "the left-hand-side of a simple assignment must be an identifer")
    return {}, false
  }

  lhs_node := ast.to_node(lhs_token)
  append(&node.children, lhs_node)

  lhs_type_node := lhs_node.data_type
  if lhs_type_node != nil && lhs_type_node.value == "[procedure]"
  {
    ctx.return_value_required = len(lhs_type_node.children) == 2
  }

  operator_token, operator_ok := tokens.next_token(stream, .equals)
  if !operator_ok
  {
    stream.error = src.to_position_message(operator_token.src_position, "the identifier in the left-hand-side of a simple assignment must be followed by an '='")
    return {}, false
  }

  operator_node := ast.to_node(operator_token)
  append(&node.children, operator_node)

  rhs_node := parse_scope_or_rhs_expression(ctx, stream) or_return
  append(&node.children, rhs_node)

  return node, true
}
