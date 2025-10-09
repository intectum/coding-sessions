package parsing

import "../ast"
import "../tokens"

parse_lhs_declaration :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  node = parse_identifier(stream) or_return

  tokens.next_token(stream, .colon) or_return

  type_stream := stream^
  type_node, type_ok := parse_primary(&type_stream, .type)
  if type_ok
  {
    stream^ = type_stream
    append(&node.children, type_node)
  }
  else
  {
    append(&node.children, ast.node { type = .type, value = "[none]" })
  }

  if tokens.peek_token(stream).type == .at
  {
    tokens.next_token(stream, .at) or_return

    node.allocator = (tokens.next_token(stream, .identifier) or_return).value
  }

  return node, true
}
