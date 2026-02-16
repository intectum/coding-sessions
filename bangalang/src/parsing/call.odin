package parsing

import "../ast"
import "../src"
import "../tokens"

parse_call :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .call,
    src_position = tokens.peek_token(stream).src_position
  })

  opening_bracket_token, opening_bracket_ok := tokens.next_token(stream, .opening_bracket)
  if !opening_bracket_ok
  {
    stream.error = src.to_position_message(opening_bracket_token.src_position, "procedure call must begin with '('")
    return {}, false
  }

  for tokens.peek_token(stream).type != .closing_bracket
  {
    if len(node.children) > 0
    {
      comma_token, comma_ok := tokens.next_token(stream, .comma)
      if !comma_ok
      {
        stream.error = src.to_position_message(comma_token.src_position, "parameters in a procedure call must be separated by ','")
        return {}, false
      }
    }

    param_node := parse_rhs_expression(stream) or_return
    append(&node.children, param_node)
  }

  closing_bracket_token, closing_bracket_ok := tokens.next_token(stream, .closing_bracket)
  if !closing_bracket_ok
  {
    stream.error = src.to_position_message(closing_bracket_token.src_position, "procedure call must end with ')'")
    return {}, false
  }

  return node, true
}
