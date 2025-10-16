package parsing

import "../ast"
import "../tokens"

parse_break :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  node.type = .break_statement
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, .keyword, "break") or_return

  return node, true
}
