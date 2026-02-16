package parsing

import "../ast"
import "../src"
import "../tokens"

parse_scope :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .scope_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  if tokens.peek_token(stream).type == .keyword && tokens.peek_token(stream).value == "do"
  {
    tokens.next_token(stream, .keyword, "do") or_return

    statement_node := parse_statement(ctx, stream) or_return
    append(&node.children, statement_node)
  }
  else
  {
    opening_bracket_token, opening_bracket_ok := tokens.next_token(stream, .opening_curly_bracket)
    if !opening_bracket_ok
    {
      stream.error = src.to_position_message(opening_bracket_token.src_position, "scope must begin with '{{'")
      return {}, false
    }

    for tokens.peek_token(stream).type != .closing_curly_bracket
    {
      statement_node := parse_statement(ctx, stream) or_return
      append(&node.children, statement_node)
    }

    tokens.next_token(stream, .closing_curly_bracket) or_return
  }

  return node, true
}
