package parsing

import "../ast"
import "../tokens"

parse_compound_literal :: proc(stream: ^tokens.stream) -> (node: ^ast.node, ok: bool)
{
  dummy_ctx: parsing_context

  node = ast.make_node({
    type = .compound_literal,
    src_position = tokens.peek_token(stream).src_position
  })

  tokens.next_token(stream, .opening_curly_bracket) or_return

  assignment_members := false
  expression_members := false
  for tokens.peek_token(stream).type != .closing_curly_bracket
  {
    if len(node.children) > 0
    {
      tokens.next_token(stream, .comma) or_return
    }

    member_assignment_stream := stream^
    member_assignment_node, member_assignment_ok := parse_simple_assignment(&dummy_ctx, &member_assignment_stream)

    member_expression_stream := stream^
    member_expression_node, member_expression_ok := parse_rhs_expression(&member_expression_stream)

    assignment := member_assignment_stream.next_index > member_expression_stream.next_index
    if assignment_members || expression_members
    {
      assignment = assignment_members
    }

    if assignment
    {
      assignment_members = true

      stream^ = member_assignment_stream
      if !member_assignment_ok
      {
        return {}, false
      }

      append(&node.children, member_assignment_node)
    }
    else
    {
      expression_members = true

      stream^ = member_expression_stream
      if !member_expression_ok
      {
        return {}, false
      }

      append(&node.children, member_expression_node)
    }
  }

  tokens.next_token(stream, .closing_curly_bracket) or_return

  return node, true
}
