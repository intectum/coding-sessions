package parsing

import "../ast"
import "../tokens"

parse_lhs_expression :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  node = parse_primary(stream, .lhs) or_return

  if tokens.peek_token(stream).type == .colon
  {
    tokens.next_token(stream, .colon) or_return

    type_node := parse_primary(stream, .type) or_return

    if tokens.peek_token(stream).type == .at
    {
      tokens.next_token(stream, .at) or_return

      node.allocator = (tokens.next_token(stream, .identifier) or_return).value
    }

    append(&node.children, type_node)
  }

  return node, true
}
