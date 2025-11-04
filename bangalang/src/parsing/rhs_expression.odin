package parsing

import "core:slice"

import "../ast"
import "../tokens"

// Based on https://en.wikipedia.org/wiki/Operator-precedence_parser#Pseudocode
parse_rhs_expression :: proc(stream: ^tokens.stream) -> (node: ast.node, ok: bool)
{
  first_primary_node := parse_primary(stream, .rhs) or_return
  return parse_rhs_expression_1(stream, first_primary_node, 0)
}

parse_rhs_expression_1 :: proc(stream: ^tokens.stream, lhs: ast.node, min_precedence: int) -> (final_lhs: ast.node, ok: bool)
{
  final_lhs = lhs

  lookahead := tokens.peek_token(stream)
  for is_binary_operator(lookahead) && binary_operator_precedence(lookahead) >= min_precedence
  {
    op := lookahead
    tokens.next_token(stream, op.type) or_return
    rhs := parse_primary(stream, .rhs) or_return
    lookahead = tokens.peek_token(stream)
    for is_binary_operator(lookahead) && binary_operator_precedence(lookahead) > binary_operator_precedence(op)
    {
      // NOTE: Need to re-check pseudo code for min_precedence if adding support for right-associative operators
      rhs = parse_rhs_expression_1(stream, rhs, binary_operator_precedence(op) + 1) or_return
      lookahead = tokens.peek_token(stream)
    }

    new_lhs := ast.to_node(op)

    append(&new_lhs.children, final_lhs)
    append(&new_lhs.children, rhs)
    final_lhs = new_lhs
  }

  return final_lhs, true
}

is_binary_operator :: proc(token: tokens.token) -> bool
{
  _, binary_operator := slice.linear_search(tokens.binary_operators, token.type)
  return binary_operator
}

binary_operator_precedence :: proc(token: tokens.token) -> int
{
  #partial switch token.type
  {
  case .pipe_pipe:
    return 1
  case .ampersand_ampersand:
    return 2
  case .equals_equals, .exclamation_equals, .opening_angle_bracket, .closing_angle_bracket, .opening_angle_bracket_equals, .closing_angle_bracket_equals:
    return 3
  case .plus, .minus, .pipe:
    return 4
  case .asterisk, .backslash, .percent, .ampersand:
    return 5
  }

  assert(false, "Unsupported binary operator")
  return 0
}
