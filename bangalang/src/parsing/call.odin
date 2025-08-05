package parsing

import "../ast"
import "../tokens"

parse_call :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  node.type = .call
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, .opening_bracket) or_return

  for tokens.peek_token(stream).type != .closing_bracket
  {
    param_node := parse_rhs_expression(stream) or_return
    append(&node.children, param_node)

    // TODO allows comma at end of params
    if tokens.peek_token(stream).type != .closing_bracket
    {
      tokens.next_token(stream, .comma) or_return
    }
  }

  tokens.next_token(stream, .closing_bracket) or_return

  return node, true
}
