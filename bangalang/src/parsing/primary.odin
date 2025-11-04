package parsing

import "../ast"
import "../src"
import "../tokens"

primary_type :: enum
{
  none,
  lhs,
  rhs,
  type
}

parse_primary :: proc(stream: ^tokens.stream, type: primary_type) -> (node: ast.node, ok: bool)
{
  node.src_position = tokens.peek_token(stream).src_position

  #partial switch tokens.peek_token(stream).type
  {
  case .directive:
    if type == .lhs
    {
      stream.error = src.to_position_message(node.src_position, "A left-hand-side primary cannot contain a directive")
      return {}, false
    }

    directive := (tokens.next_token(stream, .directive) or_return).value

    node = parse_primary(stream, type) or_return
    node.directive = directive
  case .hat:
    if type == .lhs
    {
      stream.error = src.to_position_message(node.src_position, "A left-hand-side primary cannot be referenced")
      return {}, false
    }

    tokens.next_token(stream, .hat) or_return

    node.type = .reference

    primary_node := parse_primary(stream, type) or_return
    append(&node.children, primary_node)
  case .minus:
    if type != .rhs
    {
      stream.error = src.to_position_message(node.src_position, "Only a right-hand-side primary can be negated")
      return {}, false
    }

    tokens.next_token(stream, .minus) or_return

    node.type = .negate

    primary_node := parse_primary(stream, type) or_return
    append(&node.children, primary_node)
  case .exclamation:
    if type != .rhs
    {
      stream.error = src.to_position_message(node.src_position, "Only a right-hand-side primary can be inverted")
      return {}, false
    }

    tokens.next_token(stream, .exclamation) or_return

    node.type = .not

    primary_node := parse_primary(stream, type) or_return
    append(&node.children, primary_node)
  case .opening_bracket:
    tokens.next_token(stream, .opening_bracket) or_return

    if type == .rhs
    {
      node = parse_rhs_expression(stream) or_return
    }
    else
    {
      node = parse_primary(stream, type) or_return
    }

    tokens.next_token(stream, .closing_bracket) or_return
  case .identifier:
    token := tokens.next_token(stream, .identifier) or_return
    node = ast.to_node(token)

    if type == .type
    {
      node.type = .type
    }
  case .keyword:
    if type == .lhs
    {
      stream.error = src.to_position_message(node.src_position, "A left-hand-side primary cannot contain a type literal")
      return {}, false
    }

    switch tokens.peek_token(stream).value
    {
    case "struct":
      node = parse_struct_type(stream) or_return
    case "proc":
      node = parse_procedure_type(stream) or_return
    case:
      stream.error = src.to_position_message(node.src_position, "Invalid keyword '%s'", tokens.peek_token(stream).value)
      return {}, false
    }
  case .char:
    if type != .rhs
    {
      stream.error = src.to_position_message(node.src_position, "Only a right-hand-side primary can contain a char literal")
      return {}, false
    }

    node.type = .char_literal
    node.value = (tokens.next_token(stream, .char) or_return).value
  case .string_:
    if type != .rhs
    {
      stream.error = src.to_position_message(node.src_position, "Only a right-hand-side primary can contain a string literal")
      return {}, false
    }

    node.type = .string_literal
    node.value = (tokens.next_token(stream, .string_) or_return).value
  case .number:
    if type != .rhs
    {
      stream.error = src.to_position_message(node.src_position, "Only a right-hand-side primary can contain a number literal")
      return {}, false
    }

    node.type = .number_literal
    node.value = (tokens.next_token(stream, .number) or_return).value
  case .boolean:
    if type != .rhs
    {
      stream.error = src.to_position_message(node.src_position, "Only a right-hand-side primary can contain a boolean literal")
      return {}, false
    }

    node.type = .boolean_literal
    node.value = (tokens.next_token(stream, .boolean) or_return).value
  case .opening_curly_bracket:
    node = parse_compound_literal(stream) or_return
  case .nil_:
    if type != .rhs
    {
      stream.error = src.to_position_message(node.src_position, "Only a right-hand-side primary can contain a nil")
      return {}, false
    }

    node.type = .nil_literal
    node.value = (tokens.next_token(stream, .nil_) or_return).value
  case:
    stream.error = src.to_position_message(node.src_position, "Invalid token type '%s'", tokens.peek_token(stream).type)
    return {}, false
  }

  found_suffix := true
  for found_suffix
  {
    #partial switch tokens.peek_token(stream).type
    {
    case .hat:
      if type == .type
      {
        stream.error = src.to_position_message(node.src_position, "A type primary cannot be dereferenced")
        return {}, false
      }

      tokens.next_token(stream, .hat) or_return

      child_node := node

      node = {
        type = .dereference,
        src_position = child_node.src_position
      }

      append(&node.children, child_node)
    case .opening_square_bracket:
      tokens.next_token(stream, .opening_square_bracket) or_return

      child_node := node

      node = {
        type = type == .type ? .type : .index,
        value = type == .type ? "[slice]" : "",
        src_position = child_node.src_position
      }

      append(&node.children, child_node)

      if type == .type
      {
        if tokens.peek_token(stream).type != .closing_square_bracket
        {
          node.value = "[array]"

          expression_node := parse_rhs_expression(stream) or_return
          append(&node.children, expression_node)
        }
      }
      else
      {
        if tokens.peek_token(stream).type == .closing_square_bracket
        {
          append(&node.children, ast.node { type = .nil_literal })

          append(&node.children, ast.node { type = .nil_literal })
        }
        else if tokens.peek_token(stream).type == .colon
        {
          append(&node.children, ast.node { type = .nil_literal })

          tokens.next_token(stream, .colon) or_return

          end_expression_node := parse_rhs_expression(stream) or_return
          append(&node.children, end_expression_node)
        }
        else
        {
          start_expression_node := parse_rhs_expression(stream) or_return
          append(&node.children, start_expression_node)

          if tokens.peek_token(stream).type == .colon
          {
            tokens.next_token(stream, .colon) or_return

            if tokens.peek_token(stream).type == .closing_square_bracket
            {
              append(&node.children, ast.node { type = .nil_literal })
            }
            else
            {
              end_expression_node := parse_rhs_expression(stream) or_return
              append(&node.children, end_expression_node)
            }
          }
        }
      }

      tokens.next_token(stream, .closing_square_bracket) or_return
    case .period:
      tokens.next_token(stream, .period) or_return

      child_node := node

      node = parse_primary(stream, type) or_return

      leaf_node := &node
      for len(leaf_node.children) > 0
      {
        leaf_node = &leaf_node.children[0]
      }

      append(&leaf_node.children, child_node)
    case .opening_bracket:
      if type != .rhs
      {
        stream.error = src.to_position_message(node.src_position, "Only a right-hand-side primary can contain a call")
        return {}, false
      }

      child_node := node

      node = parse_call(stream) or_return

      inject_at(&node.children, 0, child_node)
    case:
      found_suffix = false
    }
  }

  return node, true
}
