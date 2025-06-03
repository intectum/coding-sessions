package main

import "core:fmt"
import "core:os"
import "core:strconv"

parse_program :: proc(stream: ^token_stream) -> (nodes: [dynamic]ast_node, ok: bool)
{
    for stream.next_index < len(stream.tokens)
    {
        statement_node := parse_statement(stream) or_return
        append(&nodes, statement_node)
    }

    return nodes, true
}

parse_statement :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    #partial switch peek_token(stream).type
    {
    case .KEYWORD:
        if peek_token(stream).value == "if"
        {
            return parse_if(stream)
        }
        else if peek_token(stream).value == "for"
        {
            return parse_for(stream)
        }
        else if peek_token(stream).value == "return"
        {
            return parse_return(stream)
        }
    case .OPENING_SQUIGGLY_BRACKET:
        return parse_scope(stream)
    }

    return parse_assignment_or_rhs_expression(stream)
}

parse_if :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .IF
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.KEYWORD, "if") or_return

    next_token(stream, .OPENING_BRACKET) or_return

    expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, expression_node)

    next_token(stream, .CLOSING_BRACKET) or_return

    statement_node := parse_statement(stream) or_return
    append(&node.children, statement_node)

    for peek_token(stream).value == "else" && peek_token(stream, 1).value == "if"
    {
        next_token(stream, token_type.KEYWORD, "else") or_return
        next_token(stream, token_type.KEYWORD, "if") or_return

        next_token(stream, .OPENING_BRACKET) or_return

        else_if_expression_node := parse_rhs_expression(stream) or_return
        append(&node.children, else_if_expression_node)

        next_token(stream, .CLOSING_BRACKET) or_return

        else_if_statement_node := parse_statement(stream) or_return
        append(&node.children, else_if_statement_node)
    }

    if peek_token(stream).value == "else"
    {
        next_token(stream, token_type.KEYWORD, "else") or_return

        else_statement_node := parse_statement(stream) or_return
        append(&node.children, else_statement_node)
    }

    return node, true
}

parse_for :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .FOR
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.KEYWORD, "for") or_return

    next_token(stream, .OPENING_BRACKET) or_return

    // TODO this is way too manual checking...
    if peek_token(stream).type == .IDENTIFIER && peek_token(stream, 1).type == .COLON
    {
        pre_assignment_node := parse_assignment(stream) or_return
        append(&node.children, pre_assignment_node)

        next_token(stream, .COMMA) or_return
    }

    expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, expression_node)

    if peek_token(stream).type == .COMMA
    {
        next_token(stream, .COMMA) or_return

        post_assignment_node := parse_assignment(stream) or_return
        append(&node.children, post_assignment_node)
    }

    next_token(stream, .CLOSING_BRACKET) or_return

    statement_node := parse_statement(stream) or_return
    append(&node.children, statement_node)

    return node, true
}

parse_scope :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .SCOPE
    node.file_info = peek_token(stream).file_info

    next_token(stream, .OPENING_SQUIGGLY_BRACKET) or_return

    for stream.next_index < len(stream.tokens)
    {
        if peek_token(stream).type == .CLOSING_SQUIGGLY_BRACKET
        {
            next_token(stream, .CLOSING_SQUIGGLY_BRACKET) or_return
            return node, true
        }

        statement_node := parse_statement(stream) or_return
        append(&node.children, statement_node)
    }

    stream.error = "Scope never ends"
    return {}, false
}

parse_return :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .RETURN
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.KEYWORD, "return") or_return

    expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, expression_node)

    return node, true
}

parse_assignment_or_rhs_expression :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    assignment_stream := stream^
    assignment_node, assignment_ok := parse_assignment(&assignment_stream)

    rhs_expression_stream := stream^
    rhs_expression_node, rhs_expression_ok := parse_rhs_expression(&rhs_expression_stream)

    if !assignment_ok && !rhs_expression_ok
    {
        if rhs_expression_stream.next_index >= assignment_stream.next_index
        {
            stream^ = rhs_expression_stream
        }
        else
        {
            stream^ = assignment_stream
        }

        return {}, false
    }

    if !assignment_ok
    {
        stream^ = rhs_expression_stream
        return rhs_expression_node, true
    }
    else if !rhs_expression_ok
    {
        stream^ = assignment_stream
        return assignment_node, true
    }
    else if rhs_expression_stream.next_index >= assignment_stream.next_index
    {
        stream^ = rhs_expression_stream
        return rhs_expression_node, true
    }
    else
    {
        stream^ = assignment_stream
        return assignment_node, true
    }
}

parse_assignment :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .ASSIGNMENT
    node.file_info = peek_token(stream).file_info

    lhs_node := parse_lhs_expression(stream) or_return
    append(&node.children, lhs_node)

    if peek_token(stream).type == .EQUALS
    {
        next_token(stream, .EQUALS) or_return

        statement_node := parse_statement(stream) or_return
        append(&node.children, statement_node)
    }

    return node, true
}

parse_lhs_expression :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node = parse_primary(stream, true) or_return

    if peek_token(stream).type == .COLON
    {
        next_token(stream, .COLON) or_return

        type_node := parse_primary(stream, false) or_return
        append(&node.children, type_node)
    }

    return node, true
}

// Based on https://en.wikipedia.org/wiki/Operator-precedence_parser#Pseudocode
parse_rhs_expression :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    first_primary_node := parse_primary(stream, false) or_return
    return parse_rhs_expression_1(stream, first_primary_node, 0)
}

parse_rhs_expression_1 :: proc(stream: ^token_stream, lhs: ast_node, min_precedence: int) -> (final_lhs: ast_node, ok: bool)
{
    final_lhs = lhs

    lookahead := peek_token(stream)
    for is_binary_operator(lookahead) && binary_operator_precedence(lookahead) >= min_precedence
    {
        op := lookahead
        next_token(stream, op.type) or_return
        rhs := parse_primary(stream, false) or_return
        lookahead = peek_token(stream)
        for is_binary_operator(lookahead) && binary_operator_precedence(lookahead) > binary_operator_precedence(op)
        {
            // NOTE: Need to re-check pseudo code for min_precedence if adding support for right-associative operators
            rhs = parse_rhs_expression_1(stream, rhs, binary_operator_precedence(op) + 1) or_return
            lookahead = peek_token(stream)
        }

        new_lhs := ast_node { type = to_ast_node_type(op) }
        new_lhs.file_info = op.file_info

        append(&new_lhs.children, final_lhs)
        append(&new_lhs.children, rhs)
        final_lhs = new_lhs
    }

    return final_lhs, true
}

parse_primary :: proc(stream: ^token_stream, lhs: bool) -> (node: ast_node, ok: bool)
{
    node.file_info = peek_token(stream).file_info

    if lhs
    {
        node = parse_identifier(stream) or_return
    }
    else
    {
        #partial switch peek_token(stream).type
        {
        case .DIRECTIVE:
            directive := (next_token(stream, .DIRECTIVE) or_return).value

            node = parse_primary(stream, lhs) or_return
            node.directive = directive
        case .HAT:
            next_token(stream, .HAT) or_return

            node.type = .REFERENCE

            primary_node := parse_primary(stream, lhs) or_return
            append(&node.children, primary_node)
        case .MINUS:
            next_token(stream, .MINUS) or_return

            node.type = .NEGATE

            primary_node := parse_primary(stream, lhs) or_return
            append(&node.children, primary_node)
        case .OPENING_BRACKET:
            next_token(stream, .OPENING_BRACKET) or_return

            node = parse_rhs_expression(stream) or_return

            next_token(stream, .CLOSING_BRACKET) or_return
        case .IDENTIFIER:
            if peek_token(stream, 1).type == .OPENING_BRACKET
            {
                node = parse_call(stream) or_return
            }
            else
            {
                node = parse_identifier(stream) or_return
            }
        case .KEYWORD:
            switch peek_token(stream).value
            {
            case "struct":
                node = parse_struct_type(stream) or_return
            case "proc":
                node = parse_procedure_type(stream) or_return
            case:
                stream.error = "Failed to parse primary"
                return {}, false
            }
        case .STRING:
            node.type = .STRING
            node.value = (next_token(stream, .STRING) or_return).value
        case .CSTRING:
            node.type = .CSTRING
            node.value = (next_token(stream, .CSTRING) or_return).value
        case .NUMBER:
            node.type = .NUMBER
            node.value = (next_token(stream, .NUMBER) or_return).value
        case .BOOLEAN:
            node.type = .BOOLEAN
            node.value = (next_token(stream, .BOOLEAN) or_return).value
        case .NIL:
            node.type = .NIL
            node.value = (next_token(stream, .NIL) or_return).value
        case:
            stream.error = "Failed to parse primary"
            return {}, false
        }
    }

    #partial switch peek_token(stream).type
    {
    case .HAT:
        next_token(stream, .HAT) or_return

        child_node := node

        node = {
            type = .DEREFERENCE,
            file_info = child_node.file_info
        }

        append(&node.children, child_node)
    case .OPENING_SQUARE_BRACKET:
        next_token(stream, .OPENING_SQUARE_BRACKET) or_return

        child_node := node

        node = {
            type = .INDEX,
            file_info = child_node.file_info
        }

        append(&node.children, child_node)

        expression_node := parse_rhs_expression(stream) or_return
        append(&node.children, expression_node)

        next_token(stream, .CLOSING_SQUARE_BRACKET) or_return
    case .PERIOD:
        next_token(stream, .PERIOD) or_return

        child_node := node

        node = parse_primary(stream, lhs) or_return

        leaf_node := &node
        for len(leaf_node.children) == 1
        {
            leaf_node = &leaf_node.children[0]
        }

        append(&leaf_node.children, child_node)
    }

    return node, true
}

parse_call :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .CALL
    node.file_info = peek_token(stream).file_info

    name_node := parse_identifier(stream) or_return
    append(&node.children, name_node)

    next_token(stream, .OPENING_BRACKET) or_return

    for peek_token(stream).type != .CLOSING_BRACKET
    {
        param_node := parse_rhs_expression(stream) or_return
        append(&node.children, param_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .CLOSING_BRACKET
        {
            next_token(stream, .COMMA) or_return
        }
    }

    next_token(stream, .CLOSING_BRACKET) or_return

    return node, true
}

parse_struct_type :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .TYPE
    node.value = "struct"
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.KEYWORD, "struct") or_return

    next_token(stream, .OPENING_SQUIGGLY_BRACKET) or_return

    for peek_token(stream).type != .CLOSING_SQUIGGLY_BRACKET
    {
        member_node := parse_identifier(stream) or_return

        next_token(stream, .COLON) or_return

        member_type_node := parse_primary(stream, false) or_return
        append(&member_node.children, member_type_node)

        append(&node.children, member_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .CLOSING_SQUIGGLY_BRACKET
        {
            next_token(stream, .COMMA) or_return
        }
    }

    next_token(stream, .CLOSING_SQUIGGLY_BRACKET) or_return

    return node, true
}

parse_procedure_type :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .TYPE
    node.value = "procedure"
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.KEYWORD, "proc") or_return

    next_token(stream, .OPENING_BRACKET) or_return

    params_type_node := ast_node { type = .TYPE, value = "parameters" }

    for peek_token(stream).type != .CLOSING_BRACKET
    {
        param_node := parse_identifier(stream) or_return

        next_token(stream, .COLON) or_return

        param_type_node := parse_primary(stream, false) or_return
        append(&param_node.children, param_type_node)

        append(&params_type_node.children, param_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .CLOSING_BRACKET
        {
            next_token(stream, .COMMA) or_return
        }
    }

    append(&node.children, params_type_node)

    next_token(stream, .CLOSING_BRACKET) or_return

    if peek_token(stream).type == .ARROW
    {
        next_token(stream, .ARROW) or_return

        return_type_node := parse_primary(stream, false) or_return
        append(&node.children, return_type_node)
    }

    return node, true
}

parse_identifier :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    token := next_token(stream, .IDENTIFIER) or_return
    node = ast_node {
        type = .IDENTIFIER,
        value = token.value,
        file_info = token.file_info
    }

    return node, true
}

is_binary_operator :: proc(token: token) -> bool
{
    #partial switch token.type
    {
    case .EQUALS_EQUALS, .EXCLAMATION_EQUALS, .OPENING_ANGLE_BRACKET, .CLOSING_ANGLE_BRACKET, .OPENING_ANGLE_BRACKET_EQUALS, .CLOSING_ANGLE_BRACKET_EQUALS, .PLUS, .MINUS, .ASTERISK, .BACKSLASH, .PERCENT:
        return true
    case:
        return false
    }
}

binary_operator_precedence :: proc(token: token) -> int
{
    #partial switch token.type
    {
    case .EQUALS_EQUALS, .EXCLAMATION_EQUALS, .OPENING_ANGLE_BRACKET, .CLOSING_ANGLE_BRACKET, .OPENING_ANGLE_BRACKET_EQUALS, .CLOSING_ANGLE_BRACKET_EQUALS:
        return 1
    case .PLUS, .MINUS:
        return 2
    case .ASTERISK, .BACKSLASH, .PERCENT:
        return 3
    }

    assert(false, "Unsupported binary operator")
    return 0
}

to_ast_node_type :: proc(token: token) -> ast_node_type
{
    #partial switch token.type
    {
    case .EQUALS_EQUALS:
        return .EQUAL
    case .EXCLAMATION_EQUALS:
        return .NOT_EQUAL
    case .OPENING_ANGLE_BRACKET:
        return .LESS_THAN
    case .CLOSING_ANGLE_BRACKET:
        return .GREATER_THAN
    case .OPENING_ANGLE_BRACKET_EQUALS:
        return .LESS_THAN_OR_EQUAL
    case .CLOSING_ANGLE_BRACKET_EQUALS:
        return .GREATER_THAN_OR_EQUAL
    case .PLUS:
        return .ADD
    case .MINUS:
        return .SUBTRACT
    case .ASTERISK:
        return .MULTIPLY
    case .BACKSLASH:
        return .DIVIDE
    case .PERCENT:
        return .MODULO
    }

    assert(false, "Unsupported ast node type")
    return .EQUAL
}
