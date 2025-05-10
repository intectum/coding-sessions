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
    EQUAL,
    NOT_EQUAL,
    LESS_THAN,
    GREATER_THAN,
    LESS_THAN_OR_EQUAL,
    GREATER_THAN_OR_EQUAL,
    ADD,
    SUBTRACT,
    MULTIPLY,
    DIVIDE,
    REFERENCE,
    DEREFERENCE,
    NEGATE,
    INDEX,
    CALL,
    IDENTIFIER,
    STRING,
    CSTRING,
    NUMBER,
    BOOLEAN,
    NIL
}

data_type :: struct
{
    name: string,
    length: int,

    is_reference: bool
}

ast_node :: struct
{
    type: ast_node_type,
    value: string,
    directive: string,
    data_type: data_type,
    data_index: int,
    children: [dynamic]ast_node,
    line_number: int,
    column_number: int
}

comparison_operators: []ast_node_type = { .EQUAL, .NOT_EQUAL, .LESS_THAN, .GREATER_THAN, .LESS_THAN_OR_EQUAL, .GREATER_THAN_OR_EQUAL }

parse_program :: proc(stream: ^token_stream) -> (nodes: [dynamic]ast_node)
{
    for stream.next_index < len(stream.tokens)
    {
        // TODO this is way too manual checking...
        if peek_token(stream).type == .IDENTIFIER && peek_token(stream, 1).type == .COLON && (peek_token(stream, 2).value == "#extern" || peek_token(stream, 2).value == "proc")
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

    if peek_token(stream).type == .DIRECTIVE
    {
        node.directive = next_token(stream, []token_type { .DIRECTIVE }).value
    }

    next_token(stream, token_type.KEYWORD, "proc")
    next_token(stream, []token_type { .OPENING_BRACKET })

    for peek_token(stream).type != .CLOSING_BRACKET
    {
        param_node := parse_identifier(stream)

        next_token(stream, []token_type { .COLON })

        parse_type(stream, &param_node)

        append(&node.children, param_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .CLOSING_BRACKET
        {
            next_token(stream, []token_type { .COMMA })
        }
    }

    next_token(stream, []token_type { .CLOSING_BRACKET })

    if peek_token(stream).type == .ARROW
    {
        next_token(stream, []token_type { .ARROW })

        parse_type(stream, &node)
    }

    if peek_token(stream).type == .EQUALS
    {
        next_token(stream, []token_type { .EQUALS })

        statement_node := parse_statement(stream)
        append(&node.children, statement_node)
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

    next_token(stream, []token_type { .OPENING_BRACKET })

    expression_node := parse_expression(stream)
    append(&node.children, expression_node)

    next_token(stream, []token_type { .CLOSING_BRACKET })

    statement_node := parse_statement(stream)
    append(&node.children, statement_node)

    for peek_token(stream).value == "else" && peek_token(stream, 1).value == "if"
    {
        next_token(stream, token_type.KEYWORD, "else")
        next_token(stream, token_type.KEYWORD, "if")

        next_token(stream, []token_type { .OPENING_BRACKET })

        else_if_expression_node := parse_expression(stream)
        append(&node.children, else_if_expression_node)

        next_token(stream, []token_type { .CLOSING_BRACKET })

        else_if_statement_node := parse_statement(stream)
        append(&node.children, else_if_statement_node)
    }

    if peek_token(stream).value == "else"
    {
        next_token(stream, token_type.KEYWORD, "else")

        else_statement_node := parse_statement(stream)
        append(&node.children, else_statement_node)
    }

    return
}

parse_for :: proc(stream: ^token_stream) -> (node: ast_node)
{
    node.type = .FOR
    node.line_number = peek_token(stream).line_number
    node.column_number = peek_token(stream).column_number

    next_token(stream, token_type.KEYWORD, "for")

    next_token(stream, []token_type { .OPENING_BRACKET })

    // TODO this is way too manual checking...
    if peek_token(stream).type == .IDENTIFIER && peek_token(stream, 1).type == .COLON
    {
        declaration_node := parse_declaration(stream)
        append(&node.children, declaration_node)

        next_token(stream, []token_type { .COMMA })
    }

    expression_node := parse_expression(stream)
    append(&node.children, expression_node)

    if peek_token(stream).type == .COMMA
    {
        next_token(stream, []token_type { .COMMA })

        assignment_node := parse_assignment(stream)
        append(&node.children, assignment_node)
    }

    next_token(stream, []token_type { .CLOSING_BRACKET })

    statement_node := parse_statement(stream)
    append(&node.children, statement_node)

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

    if peek_token(stream).type == .DATA_TYPE || peek_token(stream).type == .HAT
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

    #partial switch peek_token(stream).type
    {
    case .HAT:
        next_token(stream, []token_type { .HAT })

        node.type = .REFERENCE

        primary_node := parse_primary(stream)
        append(&node.children, primary_node)
    case .MINUS:
        next_token(stream, []token_type { .MINUS })

        node.type = .NEGATE

        primary_node := parse_primary(stream)
        append(&node.children, primary_node)
    case .OPENING_BRACKET:
        next_token(stream, []token_type { .OPENING_BRACKET })

        node = parse_expression(stream)

        next_token(stream, []token_type { .CLOSING_BRACKET })
    case .IDENTIFIER:
        if peek_token(stream, 1).type == .OPENING_BRACKET
        {
            node = parse_call(stream)
        }
        else
        {
            node = parse_identifier(stream)
        }
    case .STRING:
        node.type = .STRING
        node.value = next_token(stream, []token_type { .STRING }).value
    case .CSTRING:
        node.type = .CSTRING
        node.value = next_token(stream, []token_type { .CSTRING }).value
    case .NUMBER:
        node.type = .NUMBER
        node.value = next_token(stream, []token_type { .NUMBER }).value
    case .BOOLEAN:
        node.type = .BOOLEAN
        node.value = next_token(stream, []token_type { .BOOLEAN }).value
    case .NIL:
        node.type = .NIL
        node.value = next_token(stream, []token_type { .NIL }).value
    case:
        token := peek_token(stream)
        fmt.println("Failed to parse primary")
        fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
        os.exit(1)
    }

    #partial switch peek_token(stream).type
    {
    case .HAT:
        next_token(stream, []token_type { .HAT })

        child_node := node

        node = {
            type = .DEREFERENCE,
            line_number = child_node.line_number,
            column_number = child_node.column_number
        }

        append(&node.children, child_node)
    case .OPENING_SQUARE_BRACKET:
        next_token(stream, []token_type { .OPENING_SQUARE_BRACKET })

        child_node := node

        node = {
            type = .INDEX,
            data_index = strconv.atoi(next_token(stream, []token_type { .NUMBER }).value),
            line_number = child_node.line_number,
            column_number = child_node.column_number
        }

        append(&node.children, child_node)

        next_token(stream, []token_type { .CLOSING_SQUARE_BRACKET })
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

        child_node := node

        node = {
            type = .INDEX,
            data_index = strconv.atoi(next_token(stream, []token_type { .NUMBER }).value),
            line_number = child_node.line_number,
            column_number = child_node.column_number
        }

        append(&node.children, child_node)

        next_token(stream, []token_type { .CLOSING_SQUARE_BRACKET })
    }

    return
}

parse_type :: proc(stream: ^token_stream, node: ^ast_node)
{
    boundless := false
    if peek_token(stream).type == .DIRECTIVE
    {
        next_token(stream, []token_type { .DIRECTIVE })
        boundless = true
    }

    if peek_token(stream).type == .HAT
    {
        next_token(stream, []token_type { .HAT })
        node.data_type.is_reference = true
    }

    node.data_type.name = next_token(stream, []token_type { .DATA_TYPE }).value

    node.data_type.length = boundless && node.data_type.is_reference ? 0 : 1
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
    node = ast_node { .IDENTIFIER, token.value, "", { "", 1, false }, 0, {}, token.line_number, token.column_number }

    return
}

is_binary_operator :: proc(token: token) -> bool
{
    #partial switch token.type
    {
    case .EQUALS_EQUALS, .EXCLAMATION_EQUALS, .OPENING_ANGLE_BRACKET, .CLOSING_ANGLE_BRACKET, .OPENING_ANGLE_BRACKET_EQUALS, .CLOSING_ANGLE_BRACKET_EQUALS, .PLUS, .MINUS, .ASTERISK, .BACKSLASH:
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
    case .ASTERISK, .BACKSLASH:
        return 3
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
    case:
        fmt.println("Failed to find ast node type")
        fmt.printfln("Invalid token '%s' at line %i, column %i", token.value, token.line_number, token.column_number)
        os.exit(1)
    }
}
