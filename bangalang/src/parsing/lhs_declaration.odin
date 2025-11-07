package parsing

import "../ast"
import "../tokens"

parse_lhs_declaration :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  directive: string
  if tokens.peek_token(stream).type == .directive
  {
    directive = (tokens.next_token(stream, .directive) or_return).value
  }

  token := tokens.next_token(stream, .identifier) or_return
  node = ast.to_node(token)
  node.directive = directive

  tokens.next_token(stream, .colon) or_return

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
