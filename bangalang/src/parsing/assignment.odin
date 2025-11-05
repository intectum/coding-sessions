package parsing

import "core:slice"

import "../ast"
import "../tokens"

parse_assignment :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .assignment_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  lhs_node := parse_lhs_expression(stream) or_return
  append(&node.children, lhs_node)

  lhs_type_node := ast.get_type(lhs_node)
  if !ast.is_member(lhs_node) && lhs_type_node != nil && lhs_type_node.value == "[procedure]"
  {
    ctx.return_value_required = len(lhs_type_node.children) == 2
  }

  operator_token := tokens.peek_token(stream)
  _, assignment_operator := slice.linear_search(tokens.assignment_operators, operator_token.type)
  if assignment_operator
  {
    tokens.next_token(stream, operator_token.type) or_return

    operator_node := ast.to_node(operator_token)
    append(&node.children, operator_node)

    rhs_node := parse_scope_or_rhs_expression(stream, ctx) or_return
    append(&node.children, rhs_node)
  }

  return node, true
}
