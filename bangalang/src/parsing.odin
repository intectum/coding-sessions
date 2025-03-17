package main

import "core:fmt"
import "core:os"
import "core:strconv"

ast_node_type :: enum
{
    PROCEDURE,
    IF,
    FOR,
    SCOPE,
    DECLARATION,
    ASSIGNMENT,
    RETURN,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    NEGATE,
    CALL,
    IDENTIFIER,
    NUMBER
}

data_type :: struct
{
    name: string,
    length: int
}

ast_node :: struct
{
    type: ast_node_type,
    value: string,
    data_type: data_type,
    data_index: int,
    children: [dynamic]ast_node,
    line_number: int,
    column_number: int
}

parse_program :: proc(stream: ^token_stream) -> (nodes: [dynamic]ast_node)
{
    for stream.next_index < len(stream.tokens)
    {
        // TODO this is way too manual checking...
        if peek_token(stream).type == .IDENTIFIER && peek_token(stream, 1).type == .COLON && peek_token(stream, 2).type == .EQUALS && peek_token(stream, 3).value == "proc"
        {
            append(&nodes, parse_procedure(stream))
        }
        else
        {
            append(&nodes, parse_statement(stream))
        }
    }

    return
}

parse_procedure :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .PROCEDURE
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    lhs_node := parse_identifier(stream)
    append(&node.children, lhs_node)

    next_token(stream, []token_type { .COLON })
    next_token(stream, []token_type { .EQUALS })
    next_token(stream, token_type.KEYWORD, "proc")
    next_token(stream, []token_type { .OPENING_BRACKET })

    for peek_token(stream).type != .CLOSING_BRACKET
    {
        param_node := parse_identifier(stream)

        next_token(stream, []token_type { .COLON })

        param_node.data_type = { next_token(stream, []token_type { .DATA_TYPE }).value, 1 }

        append(&node.children, param_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .CLOSING_BRACKET
        {
            next_token(stream, []token_type { .COMMA })
        }
    }

    next_token(stream, []token_type { .CLOSING_BRACKET })

    next_token(stream, []token_type { .ARROW })

    node.data_type = { next_token(stream, []token_type { .DATA_TYPE }).value, 1 }

    scope_node := parse_scope(stream)
    append(&node.children, scope_node)

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
            node = parse_call(stream)
        case .OPENING_SQUARE_BRACKET:
            node = parse_assignment(stream)
        case:
            token := peek_token(stream, 1)
            fmt.println("Failed to parse statement")
            fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
            os.exit(1)
        }
    case .KEYWORD:
        if peek_token(stream).value == "for"
        {
            node = parse_for(stream)
        }
        else if peek_token(stream).value == "if"
        {
            node = parse_if(stream)
        }
        else if peek_token(stream).value == "return"
        {
            node = parse_return(stream)
        }
        else
        {
            token := peek_token(stream)
            fmt.println("Failed to parse statement")
            fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
            os.exit(1)
        }
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

    for peek_token(stream).value == "else" && peek_token(stream, 1).value == "if"
    {
        next_token(stream, token_type.KEYWORD, "else")
        next_token(stream, token_type.KEYWORD, "if")

        else_if_expression_node := parse_expression(stream)
        append(&node.children, else_if_expression_node)

        else_if_scope_node := parse_scope(stream)
        append(&node.children, else_if_scope_node)
    }

    if peek_token(stream).value == "else"
    {
        next_token(stream, token_type.KEYWORD, "else")

        else_scope_node := parse_scope(stream)
        append(&node.children, else_scope_node)
    }

    return
}

parse_for :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .FOR
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    next_token(stream, token_type.KEYWORD, "for")

    // TODO this is way too manual checking...
    if peek_token(stream).type == .IDENTIFIER && peek_token(stream, 1).type == .COLON
    {
        declaration_node := parse_declaration(stream)
        append(&node.children, declaration_node)

        next_token(stream, []token_type { .COMMA })

        expression_node := parse_expression(stream)
        append(&node.children, expression_node)

        next_token(stream, []token_type { .COMMA })

        assignment_node := parse_assignment(stream)
        append(&node.children, assignment_node)
    }
    else
    {
        expression_node := parse_expression(stream)
        append(&node.children, expression_node)
    }

    scope_node := parse_scope(stream)
    append(&node.children, scope_node)

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

    lhs_node := parse_identifier(stream)

    next_token(stream, []token_type { .COLON })

    if peek_token(stream).type == .DATA_TYPE
    {
        parse_type(stream, &lhs_node)
    }

    append(&node.children, lhs_node)

    if peek_token(stream).type == .EQUALS
    {
        next_token(stream, []token_type { .EQUALS })

        rhs_node := parse_expression(stream)
        append(&node.children, rhs_node)
    }

    return
}

parse_assignment :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .ASSIGNMENT
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    lhs_node := parse_variable(stream)
    append(&node.children, lhs_node)

    next_token(stream, []token_type { .EQUALS })

    rhs_node := parse_expression(stream)
    append(&node.children, rhs_node)

    return
}

parse_return :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .RETURN
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    next_token(stream, token_type.KEYWORD, "return")

    expression_node := parse_expression(stream)
    append(&node.children, expression_node)

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
    }
    else if peek_token(stream).type == .IDENTIFIER
    {
        if peek_token(stream, 1).type == .OPENING_BRACKET
        {
            node = parse_call(stream)
        }
        else
        {
            node = parse_variable(stream)
        }
    }
    else if peek_token(stream).type == .MINUS
    {
        next_token(stream, []token_type { .MINUS })

        node.type = .NEGATE

        primary_node := parse_primary(stream)
        append(&node.children, primary_node)
    }
    else if peek_token(stream).type == .NUMBER
    {
        node.type = .NUMBER
        node.value = next_token(stream, []token_type { .NUMBER }).value
    }
    else
    {
        token := peek_token(stream)
        fmt.println("Failed to parse primary")
        fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
        os.exit(1)
    }

    return
}

parse_call :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .CALL
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    name_node := parse_identifier(stream)
    append(&node.children, name_node)

    next_token(stream, []token_type { .OPENING_BRACKET })

    for peek_token(stream).type != .CLOSING_BRACKET
    {
        param_node := parse_expression(stream)
        append(&node.children, param_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .CLOSING_BRACKET
        {
            next_token(stream, []token_type { .COMMA })
        }
    }

    next_token(stream, []token_type { .CLOSING_BRACKET })

    return
}

parse_variable :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node = parse_identifier(stream)

    if peek_token(stream).type == .OPENING_SQUARE_BRACKET
    {
        next_token(stream, []token_type { .OPENING_SQUARE_BRACKET })

        node.data_index = strconv.atoi(next_token(stream, []token_type { .NUMBER }).value)

        next_token(stream, []token_type { .CLOSING_SQUARE_BRACKET })
    }

    return
}

parse_type :: proc(stream: ^token_stream, node: ^ast_node)
{
    node.data_type = { next_token(stream, []token_type { .DATA_TYPE }).value, 1 }

    if peek_token(stream).type == .OPENING_SQUARE_BRACKET
    {
        next_token(stream, []token_type { .OPENING_SQUARE_BRACKET })

        node.data_type.length = strconv.atoi(next_token(stream, []token_type { .NUMBER }).value)

        next_token(stream, []token_type { .CLOSING_SQUARE_BRACKET })
    }

    return
}

parse_identifier :: proc(stream: ^token_stream) -> (node: ast_node)
{
    token := next_token(stream, []token_type { .IDENTIFIER })
    node = ast_node { .IDENTIFIER, token.value, { "", 1 }, -1, {}, token.line_number, token.column_number }

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
