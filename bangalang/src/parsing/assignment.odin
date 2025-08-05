package parsing

import "core:slice"

import "../ast"
import "../tokens"

parse_assignment :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .assignment
  node.src_position = tokens.peek_token(stream).src_position

  lhs_node := parse_lhs_expression(stream) or_return
  append(&node.children, lhs_node)

  lhs_type_node := ast.get_type(&lhs_node)
  if !ast.is_member(&lhs_node) && lhs_type_node != nil && lhs_type_node.value == "[procedure]"
  {
    ctx.return_value_required = len(lhs_type_node.children) == 2
  }

  token := tokens.peek_token(stream)
  _, assignment_operator := slice.linear_search(tokens.assignment_operators, token.type)
  if assignment_operator
  {
    tokens.next_token(stream, token.type) or_return

    operator_node := ast.node { type = ast.to_node_type(token.type), src_position = token.src_position }
    append(&node.children, operator_node)

    statement_node := parse_statement(stream, ctx) or_return
    append(&node.children, statement_node)
  }

  return node, true
}
