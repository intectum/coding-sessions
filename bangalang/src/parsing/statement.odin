package parsing

import "../ast"
import "../tokens"

parse_statement :: proc(stream: ^tokens.stream, ctx: ^parsing_context) -> (ast.node, bool)
{
  if tokens.peek_token(stream).type == .keyword
  {
    if tokens.peek_token(stream).value == "if"
    {
      return parse_if(stream, ctx)
    }
    else if tokens.peek_token(stream).value == "for"
    {
      return parse_for(stream, ctx)
    }
    else if tokens.peek_token(stream).value == "switch"
    {
      return parse_switch(stream, ctx)
    }
    else if tokens.peek_token(stream).value == "continue"
    {
      return parse_continue(stream)
    }
    else if tokens.peek_token(stream).value == "break"
    {
      return parse_break(stream)
    }
    else if tokens.peek_token(stream).value == "return"
    {
      return parse_return(stream, ctx)
    }
  }

  scope_stream := stream^
  scope_node, scope_ok := parse_scope(&scope_stream, ctx)

  assignment_stream := stream^
  assignment_node, assignment_ok := parse_assignment(&assignment_stream, ctx)

  rhs_expression_stream := stream^
  rhs_expression_node, rhs_expression_ok := parse_rhs_expression(&rhs_expression_stream)

  max_next_index := max(scope_stream.next_index, assignment_stream.next_index, rhs_expression_stream.next_index)

  if max_next_index == scope_stream.next_index
  {
    stream^ = scope_stream
    return scope_node, scope_ok
  }

  if max_next_index == rhs_expression_stream.next_index
  {
    stream^ = rhs_expression_stream
    return rhs_expression_node, rhs_expression_ok
  }

  stream^ = assignment_stream
  return assignment_node, assignment_ok
}
