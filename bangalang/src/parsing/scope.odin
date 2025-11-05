package parsing

import "../ast"
import "../src"
import "../tokens"

parse_scope :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .scope_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  if tokens.peek_token(stream).type == .keyword && tokens.peek_token(stream).value == "do"
  {
    tokens.next_token(stream, .keyword, "do") or_return

    statement_node := parse_statement(stream, ctx) or_return
    append(&node.children, statement_node)
  }
  else
  {
    tokens.next_token(stream, .opening_curly_bracket) or_return

    for tokens.peek_token(stream).type != .closing_curly_bracket
    {
      statement_node := parse_statement(stream, ctx) or_return
      append(&node.children, statement_node)
    }

    tokens.next_token(stream, .closing_curly_bracket) or_return
  }

  return node, true
}
