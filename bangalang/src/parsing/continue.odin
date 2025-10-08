package parsing

import "../ast"
import "../tokens"

parse_continue :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  node.type = .continue_
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, tokens.token_type.keyword, "continue") or_return

  return node, true
}
