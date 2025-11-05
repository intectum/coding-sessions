package parsing

import "../ast"
import "../tokens"

parse_call :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .call,
    src_position = tokens.peek_token(stream).src_position
  })

  tokens.next_token(stream, .opening_bracket) or_return

  for tokens.peek_token(stream).type != .closing_bracket
  {
    if len(node.children) > 0
    {
      tokens.next_token(stream, .comma) or_return
    }

    param_node := parse_rhs_expression(stream) or_return
    append(&node.children, param_node)
  }

  tokens.next_token(stream, .closing_bracket) or_return

  return node, true
}
