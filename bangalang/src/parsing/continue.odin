package parsing

import "../ast"
import "../src"
import "../tokens"

parse_continue :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .continue_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  comtinue_token, continue_ok := tokens.next_token(stream, .keyword, "continue")
  if !continue_ok
  {
    stream.error = src.to_position_message(comtinue_token.src_position, "continue statement must begin with 'continue'")
    return {}, false
  }

  return node, true
}
