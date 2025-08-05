package parsing

import "../ast"
import "../tokens"

parse_compound_literal :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  dummy_ctx: parsing_context

  node.type = .compound_literal
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, .opening_curly_bracket) or_return

  for tokens.peek_token(stream).type != .closing_curly_bracket
  {
    member_node := parse_assignment(stream, &dummy_ctx) or_return
    append(&node.children, member_node)

    // TODO allows comma at end of params
    if tokens.peek_token(stream).type != .closing_curly_bracket
    {
      tokens.next_token(stream, .comma) or_return
    }
  }

  tokens.next_token(stream, .closing_curly_bracket) or_return

  return node, true
}
