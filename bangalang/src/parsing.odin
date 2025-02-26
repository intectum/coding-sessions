package main

import "core:fmt"
import "core:os"

ast_node_type :: enum
{
    IF,
    SCOPE,
    DECLARATION,
    ASSIGNMENT,
    EXIT,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NEGATE,
    IDENTIFIER,
    INTEGER_LITERAL
}

ast_node :: struct
{
    type: ast_node_type,
    value: string,
    children: [dynamic]ast_node,
    line_number: int,
    column_number: int
}

parse_program :: proc(stream: ^token_stream) -> (nodes: [dynamic]ast_node)
{
    for stream.next_index < len(stream.tokens)
    {
        append(&nodes, parse_statement(stream))
    }

    return
}

parse_statement :: proc(stream: ^token_stream) -> (node: ast_node)
{
    #partial switch peek_token(stream).type
    {
    case .IDENTIFIER:
        #partial switch peek_token(stream, 1).type
        {
        case .COLON:
            node = parse_declaration(stream)
        case .EQUALS:
            node = parse_assignment(stream)
        case .OPENING_BRACKET:
            node = parse_exit(stream)
        case:
            token := peek_token(stream, 1)
            fmt.println("Failed to parse statement")
            fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
            os.exit(1)
        }
    case .KEYWORD:
        node = parse_if(stream)
    case .OPENING_SQUIGGLY_BRACKET:
        node = parse_scope(stream)
    case:
        token := peek_token(stream)
        fmt.println("Failed to parse statement")
        fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
        os.exit(1)
    }

    return
}

parse_if :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .IF
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    next_token(stream, token_type.KEYWORD, "if")

    expression_node := parse_expression(stream)
    append(&node.children, expression_node)

    scope_node := parse_scope(stream)
    append(&node.children, scope_node)

    if peek_token(stream).value == "else"
    {
        next_token(stream, token_type.KEYWORD, "else")

        else_scope_node := parse_scope(stream)
        append(&node.children, else_scope_node)
    }

    return
}

parse_scope :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .SCOPE
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    next_token(stream, []token_type { .OPENING_SQUIGGLY_BRACKET })

    for stream.next_index < len(stream.tokens)
    {
        if peek_token(stream).type == .CLOSING_SQUIGGLY_BRACKET
        {
            next_token(stream, []token_type { .CLOSING_SQUIGGLY_BRACKET })
            return
        }

        append(&node.children, parse_statement(stream))
    }

    fmt.println("Scope never ends")
    os.exit(1)
}

parse_declaration :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .DECLARATION
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    lhs_token := next_token(stream, []token_type { .IDENTIFIER })
    lhs_node := ast_node { .IDENTIFIER, lhs_token.value, {}, lhs_token.line_number, lhs_token.column_number }
    append(&node.children, lhs_node)

    next_token(stream, []token_type { .COLON })
    next_token(stream, []token_type { .EQUALS })

    rhs_node := parse_expression(stream)
    append(&node.children, rhs_node)

    return
}

parse_assignment :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .ASSIGNMENT
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    lhs_token := next_token(stream, []token_type { .IDENTIFIER })
    lhs_node := ast_node { .IDENTIFIER, lhs_token.value, {}, lhs_token.line_number, lhs_token.column_number }
    append(&node.children, lhs_node)

    next_token(stream, []token_type { .EQUALS })

    rhs_node := parse_expression(stream)
    append(&node.children, rhs_node)

    return
}

parse_exit :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .EXIT
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    exit_token := next_token(stream, []token_type { .IDENTIFIER })
    if exit_token.value != "exit"
    {
        fmt.println("Failed to parse exit")
        fmt.println("That doesn't say exit!")
        fmt.printfln("Invalid token '%s' at line %i, column %i", exit_token.value, exit_token.line_number, exit_token.column_number)
        os.exit(1)
    }

    next_token(stream, []token_type { .OPENING_BRACKET })

    param_node := parse_expression(stream)
    append(&node.children, param_node)

    next_token(stream, []token_type { .CLOSING_BRACKET })

    return
}

// Based on https://en.wikipedia.org/wiki/Operator-precedence_parser#Pseudocode
parse_expression :: proc(stream: ^token_stream) -> (node: ast_node)
{
    return parse_expression_1(stream, parse_primary(stream), 0)
}

parse_expression_1 :: proc(stream: ^token_stream, lhs: ast_node, min_precedence: int) -> (final_lhs: ast_node)
{
    final_lhs = lhs

    lookahead := peek_token(stream)
    for is_binary_operator(lookahead) && binary_operator_precedence(lookahead) >= min_precedence
    {
        op := lookahead
        next_token(stream)
        rhs := parse_primary(stream)
        lookahead = peek_token(stream)
        for is_binary_operator(lookahead) && binary_operator_precedence(lookahead) > binary_operator_precedence(op)
        {
            // NOTE: Need to re-check pseudo code for min_precedence if adding support for right-associative operators
            rhs = parse_expression_1(stream, rhs, binary_operator_precedence(op) + 1)
            lookahead = peek_token(stream)
        }

        new_lhs := ast_node { type = to_ast_node_type(op) }
        new_lhs.line_number = op.line_number
        new_lhs.column_number = op.column_number

        append(&new_lhs.children, final_lhs)
        append(&new_lhs.children, rhs)
        final_lhs = new_lhs
    }

    return
}

parse_primary :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    if peek_token(stream).type == .OPENING_BRACKET
    {
        next_token(stream, []token_type { .OPENING_BRACKET })

        node = parse_expression(stream)

        next_token(stream, []token_type { .CLOSING_BRACKET })

        return
    }

    if peek_token(stream).type == .MINUS
    {
        next_token(stream, []token_type { .MINUS })

        node.type = .NEGATE

        primary_node := parse_primary(stream)
        append(&node.children, primary_node)

        return
    }

    token := next_token(stream, []token_type { .IDENTIFIER, .INTEGER_LITERAL })

    node.value = token.value

    #partial switch token.type
    {
    case .IDENTIFIER:
        node.type = .IDENTIFIER
    case .INTEGER_LITERAL:
        node.type = .INTEGER_LITERAL
    case:
        fmt.println("Failed to parse primary")
        fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
        os.exit(1)
    }

    return
}

is_binary_operator :: proc(token: token) -> bool
{
    #partial switch token.type
    {
    case .PLUS:
        return true
    case .MINUS:
        return true
    case .ASTERISK:
        return true
    case .BACKSLASH:
        return true
    case:
        return false
    }
}

binary_operator_precedence :: proc(token: token) -> int
{
    #partial switch token.type
    {
    case .PLUS:
        return 1
    case .MINUS:
        return 1
    case .ASTERISK:
        return 2
    case .BACKSLASH:
        return 2
    case:
        fmt.println("Failed to determine binary operator precedence")
        fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
        os.exit(1)
    }
}

to_ast_node_type :: proc(token: token) -> ast_node_type
{
    #partial switch token.type
    {
    case .PLUS:
        return .ADD
    case .MINUS:
        return .SUBTRACT
    case .ASTERISK:
        return .MULTIPLY
    case .BACKSLASH:
        return .DIVIDE
    case:
        fmt.println("Failed to find ast node type")
        fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
        os.exit(1)
    }
}
