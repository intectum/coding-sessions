package parsing

import "../ast"
import "../src"
import "../tokens"

parse_struct_type :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .type,
    value = "[struct]",
    src_position = tokens.peek_token(stream).src_position
  })

  struct_token, struct_ok := tokens.next_token(stream, .keyword, "struct")
  if !struct_ok
  {
    stream.error = src.to_position_message(struct_token.src_position, "struct type must begin with 'struct'")
    return {}, false
  }

  opening_bracket_token, opening_bracket_ok := tokens.next_token(stream, .opening_curly_bracket)
  if !opening_bracket_ok
  {
    stream.error = src.to_position_message(opening_bracket_token.src_position, "'struct' must be followed by '{{'")
    return {}, false
  }

  for tokens.peek_token(stream).type != .closing_curly_bracket
  {
    if len(node.children) > 0
    {
      comma_token, comma_ok := tokens.next_token(stream, .comma)
      if !comma_ok
      {
        stream.error = src.to_position_message(comma_token.src_position, "members in a struct type must be separated by ','")
        return {}, false
      }
    }

    member_token, member_ok := tokens.next_token(stream, .identifier)
    if !member_ok
    {
      stream.error = src.to_position_message(member_token.src_position, "members in a struct type must begin with an identifier")
      return {}, false
    }

    member_node := ast.to_node(member_token)

    colon_token, colon_ok := tokens.next_token(stream, .colon)
    if !colon_ok
    {
      stream.error = src.to_position_message(colon_token.src_position, "member identifiers must be followed by a ':'")
      return {}, false
    }

    member_node.data_type = parse_primary(stream, .type) or_return

    append(&node.children, member_node)
  }

  closing_bracket_token, closing_bracket_ok := tokens.next_token(stream, .closing_curly_bracket)
  if !closing_bracket_ok
  {
    stream.error = src.to_position_message(closing_bracket_token.src_position, "struct type must end with '}'")
    return {}, false
  }

  return node, true
}
