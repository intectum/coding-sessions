package parsing

import "../ast"
import "../tokens"

parse_enum_type :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .type,
    value = "[enum]",
    src_position = tokens.peek_token(stream).src_position
  })

  tokens.next_token(stream, .keyword, "enum") or_return

  tokens.next_token(stream, .opening_curly_bracket) or_return

  for tokens.peek_token(stream).type != .closing_curly_bracket
  {
    if len(node.children) > 0
    {
      tokens.next_token(stream, .comma) or_return
    }

    member_token := tokens.next_token(stream, .identifier) or_return
    member_node := ast.to_node(member_token)
    append(&node.children, member_node)
  }

  tokens.next_token(stream, .closing_curly_bracket) or_return

  return node, true
}
