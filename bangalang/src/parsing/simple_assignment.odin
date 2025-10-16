package parsing

import "core:slice"

import "../ast"
import "../tokens"

parse_simple_assignment :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .assignment_statement
  node.src_position = tokens.peek_token(stream).src_position

  lhs_node := parse_identifier(stream) or_return
  append(&node.children, lhs_node)

  lhs_type_node := ast.get_type(&lhs_node)
  if lhs_type_node != nil && lhs_type_node.value == "[procedure]"
  {
    ctx.return_value_required = len(lhs_type_node.children) == 2
  }

  token := tokens.next_token(stream, .equals) or_return
  operator_node := ast.node { type = ast.to_node_type(token.type), value = token.value, src_position = token.src_position }
  append(&node.children, operator_node)

  rhs_node := parse_statement(stream, ctx) or_return
  append(&node.children, rhs_node)

  return node, true
}
