package parsing

import "../ast"
import "../tokens"

parse_procedure_type :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  node.type = .type
  node.value = "[procedure]"
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, tokens.token_type.keyword, "proc") or_return

  tokens.next_token(stream, .opening_bracket) or_return

  params_type_node := ast.node { type = .type, value = "[parameters]" }

  for tokens.peek_token(stream).type != .closing_bracket
  {
    if len(params_type_node.children) > 0
    {
      tokens.next_token(stream, .comma) or_return
    }

    param_node := parse_declaration(stream) or_return
    append(&params_type_node.children, param_node)
  }

  append(&node.children, params_type_node)

  tokens.next_token(stream, .closing_bracket) or_return

  if tokens.peek_token(stream).type == .dash_greater_than
  {
    tokens.next_token(stream, .dash_greater_than) or_return

    return_type_node := parse_primary(stream, .type) or_return
    append(&node.children, return_type_node)
  }

  return node, true
}
