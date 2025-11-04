package parsing

import "../ast"
import "../tokens"

parse_struct_type :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  node.type = .type
  node.value = "[struct]"
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, .keyword, "struct") or_return

  tokens.next_token(stream, .opening_curly_bracket) or_return

  for tokens.peek_token(stream).type != .closing_curly_bracket
  {
    if len(node.children) > 0
    {
      tokens.next_token(stream, .comma) or_return
    }

    member_token := tokens.next_token(stream, .identifier) or_return
    member_node := ast.to_node(member_token)

    tokens.next_token(stream, .colon) or_return

    member_type_node := parse_primary(stream, .type) or_return
    append(&member_node.children, member_type_node)

    append(&node.children, member_node)
  }

  tokens.next_token(stream, .closing_curly_bracket) or_return

  return node, true
}
