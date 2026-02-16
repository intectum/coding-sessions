package parsing

import "../ast"
import "../src"
import "../tokens"

parse_break :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .break_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  break_token, break_ok := tokens.next_token(stream, .keyword, "break")
  if !break_ok
  {
    stream.error = src.to_position_message(break_token.src_position, "break statement must begin with 'break'")
    return {}, false
  }

  return node, true
}
