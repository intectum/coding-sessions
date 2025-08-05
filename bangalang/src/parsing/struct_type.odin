package parsing

import "../ast"
import "../tokens"

parse_struct_type :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  node.type = .type
  node.value = "[struct]"
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, tokens.token_type.keyword, "struct") or_return

  tokens.next_token(stream, .opening_curly_bracket) or_return

  for tokens.peek_token(stream).type != .closing_curly_bracket
  {
    member_node := parse_identifier(stream) or_return

    tokens.next_token(stream, .colon) or_return

    member_type_node := parse_primary(stream, .type) or_return
    append(&member_node.children, member_type_node)

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
