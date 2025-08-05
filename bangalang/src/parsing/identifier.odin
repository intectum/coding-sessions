package parsing

import "../ast"
import "../tokens"

parse_identifier :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  token := tokens.next_token(stream, .identifier) or_return
  node = ast.node {
    type = .identifier,
    value = token.value,
    src_position = token.src_position
  }

  return node, true
}
