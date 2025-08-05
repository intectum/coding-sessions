package parsing

import "core:slice"

import "../ast"
import "../tokens"

parse_for :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .for_
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, tokens.token_type.keyword, "for") or_return

  brackets := false
  if tokens.peek_token(stream).type == .opening_bracket
  {
    tokens.next_token(stream, .opening_bracket) or_return
    brackets = true
  }

  pre_statement_stream := stream^
  pre_statement_node, pre_statement_ok := parse_statement(&pre_statement_stream, ctx)

  _, statement := slice.linear_search(ast.statements, pre_statement_node.type)
  if pre_statement_ok && statement
  {
    stream^ = pre_statement_stream
    append(&node.children, pre_statement_node)

    tokens.next_token(stream, .comma) or_return
  }

  expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, expression_node)

  if tokens.peek_token(stream).type == .comma
  {
    tokens.next_token(stream, .comma) or_return

    post_statement_node := parse_statement(stream, ctx) or_return
    append(&node.children, post_statement_node)
  }

  if brackets
  {
    tokens.next_token(stream, .closing_bracket) or_return
  }

  statement_node := parse_statement(stream, ctx) or_return
  append(&node.children, statement_node)

  return node, true
}
