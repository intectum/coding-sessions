package parsing

import "core:slice"

import "../ast"
import "../src"
import "../tokens"

parse_basic_for :: proc(ctx: ^parsing_context, stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  node = ast.make_node({
    type = .basic_for_statement,
    src_position = tokens.peek_token(stream).src_position
  })

  for_token, for_ok := tokens.next_token(stream, .keyword, "for")
  if !for_ok
  {
    stream.error = src.to_position_message(for_token.src_position, "for loop must begin with 'for'")
    return {}, false
  }

  pre_declaration_stream := stream^
  pre_declaration_node, pre_declaration_ok := parse_declaration(&pre_declaration_stream)

  if pre_declaration_ok
  {
    stream^ = pre_declaration_stream
    append(&node.children, pre_declaration_node)

    comma_token, comma_ok := tokens.next_token(stream, .comma)
    if !comma_ok
    {
      stream.error = src.to_position_message(comma_token.src_position, "for loop pre-assignment must be followed by a comma")
      return {}, false
    }
  }

  expression_node := parse_rhs_expression(stream) or_return
  append(&node.children, expression_node)

  if tokens.peek_token(stream).type == .comma
  {
    tokens.next_token(stream, .comma) or_return

    post_assignment_node := parse_assignment(ctx, stream) or_return
    append(&node.children, post_assignment_node)
  }

  scope_node := parse_scope(ctx, stream) or_return
  append(&node.children, scope_node)

  return node, true
}
