package parsing

import "core:slice"

import "../ast"
import "../tokens"

parse_for :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (node: ast.node, ok: bool)
{
  node.type = .for_statement
  node.src_position = tokens.peek_token(stream).src_position

  tokens.next_token(stream, .keyword, "for") or_return

  brackets := false
  if tokens.peek_token(stream).type == .opening_bracket
  {
    tokens.next_token(stream, .opening_bracket) or_return
    brackets = true
  }

  pre_declaration_stream := stream^
  pre_declaration_node, pre_declaration_ok := parse_declaration(&pre_declaration_stream)

  if pre_declaration_ok
  {
    stream^ = pre_declaration_stream
    append(&node.children, pre_declaration_node)

    tokens.next_token(stream, .comma) or_return
  }

  expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, expression_node)

  if tokens.peek_token(stream).type == .comma
  {
    tokens.next_token(stream, .comma) or_return

    post_assignment_node := parse_assignment(stream, ctx) or_return
    append(&node.children, post_assignment_node)
  }

  if brackets
  {
    tokens.next_token(stream, .closing_bracket) or_return
  }

  statement_node := parse_statement(stream, ctx) or_return
  append(&node.children, statement_node)

  return node, true
}
