package parsing

import "../ast"
import "../tokens"

parse_if :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .if_
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, tokens.token_type.keyword, "if") or_return

  if_brackets := false
  if tokens.peek_token(stream).type == .opening_bracket
  {
    tokens.next_token(stream, .opening_bracket) or_return
    if_brackets = true
  }

  expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, expression_node)

  if if_brackets
  {
    tokens.next_token(stream, .closing_bracket) or_return
  }

  statement_node := parse_statement(stream, ctx) or_return
  append(&node.children, statement_node)

  for tokens.peek_token(stream).value == "else" && tokens.peek_token(stream, 1).value == "if"
  {
    tokens.next_token(stream, tokens.token_type.keyword, "else") or_return
    tokens.next_token(stream, tokens.token_type.keyword, "if") or_return

    else_if_brackets := false
    if tokens.peek_token(stream).type == .opening_bracket
    {
      tokens.next_token(stream, .opening_bracket) or_return
      else_if_brackets = true
    }

    else_if_expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, else_if_expression_node)

    if else_if_brackets
    {
      tokens.next_token(stream, .closing_bracket) or_return
    }

    else_if_statement_node := parse_statement(stream, ctx) or_return
    append(&node.children, else_if_statement_node)
  }

  if tokens.peek_token(stream).value == "else"
  {
    tokens.next_token(stream, tokens.token_type.keyword, "else") or_return

    else_statement_node := parse_statement(stream, ctx) or_return
    append(&node.children, else_statement_node)
  }

  return node, true
}
