package parsing

import "../ast"
import "../src"
import "../tokens"

parse_lhs_declaration :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  directive: string
  if tokens.peek_token(stream).type == .directive
  {
    directive = (tokens.next_token(stream, .directive) or_return).value
  }

  identifier_token, identifier_ok := tokens.next_token(stream, .identifier)
  if !identifier_ok
  {
    stream.error = src.to_position_message(identifier_token.src_position, "the left-hand-side of a declaration must be an identifer")
    return {}, false
  }

  node = ast.to_node(identifier_token)
  node.directive = directive

  colon_token, colon_ok := tokens.next_token(stream, .colon)
  if !colon_ok
  {
    stream.error = src.to_position_message(colon_token.src_position, "the identifier in the left-hand-side of a declaration must be followed by a ':'")
    return {}, false
  }

  type_stream := stream^
  type_node, type_ok := parse_primary(&type_stream, .type)
  if type_ok
  {
    stream^ = type_stream
    node.data_type = type_node
  }
  else
  {
    node.data_type = ast.make_node({ type = .type, value = "[none]" })
  }

  if tokens.peek_token(stream).type == .at
  {
    tokens.next_token(stream, .at) or_return

    node.allocator = parse_rhs_expression(stream) or_return
  }

  return node, true
}
