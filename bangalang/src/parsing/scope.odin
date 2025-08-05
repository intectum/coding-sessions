package parsing

import "../ast"
import "../src"
import "../tokens"

parse_scope :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .scope
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, .opening_curly_bracket) or_return

  for stream.next_index < len(stream.tokens)
  {
    if tokens.peek_token(stream).type == .closing_curly_bracket
    {
      tokens.next_token(stream, .closing_curly_bracket) or_return
      return node, true
    }

    statement_node := parse_statement(stream, ctx) or_return
    append(&node.children, statement_node)
  }

  stream.error = src.to_position_message(node.src_position, "Scope never ends")
  return {}, false
}
