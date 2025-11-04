package parsing

import "core:slice"

import "../ast"
import "../tokens"

parse_simple_assignment :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .assignment_statement
  node.src_position = tokens.peek_token(stream).src_position

  lhs_token := tokens.next_token(stream, .identifier) or_return
  lhs_node := ast.to_node(lhs_token)
  append(&node.children, lhs_node)

  lhs_type_node := ast.get_type(&lhs_node)
  if lhs_type_node != nil && lhs_type_node.value == "[procedure]"
  {
    ctx.return_value_required = len(lhs_type_node.children) == 2
  }

  operator_token := tokens.next_token(stream, .equals) or_return
  operator_node := ast.to_node(operator_token)
  append(&node.children, operator_node)

  rhs_node := parse_scope_or_rhs_expression(stream, ctx) or_return
  append(&node.children, rhs_node)

  return node, true
}
