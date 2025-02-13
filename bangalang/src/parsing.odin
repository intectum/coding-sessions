package main

import "core:fmt"
import "core:os"

ast_node_type :: enum
{
    SCOPE,
    DECLARATION_STATEMENT,
    ASSIGNMENT_STATEMENT,
    EXIT_STATEMENT,
    TERM,
    IDENTIFIER,
    INTEGER_LITERAL
}

ast_node :: struct
{
    type: ast_node_type,
    value: string,
    children: [dynamic]ast_node
}

parse_program :: proc(tokens: [dynamic]token) -> (nodes: [dynamic]ast_node)
{
    for index := 0; index < len(tokens);
    {
        node, token_count := parse_statement(tokens, index)

        append(&nodes, node)
        index += token_count
    }

    return
}

parse_statement :: proc(tokens: [dynamic]token, start_index: int) -> (node: ast_node, token_count: int)
{
    #partial switch tokens[start_index].type
    {
    case .OPENING_SQUIGGLY_BRACKET:
        scope_node, scope_token_count := parse_scope(tokens, start_index)
        node = scope_node
        token_count = scope_token_count
    case .IDENTIFIER:
        if start_index + 1 >= len(tokens)
        {
            fmt.println("Invalid statement, end of file encountered")
            os.exit(1)
        }

        #partial switch tokens[start_index + 1].type
        {
        case .COLON:
            declaration_node, declaration_token_count := parse_declaration_statement(tokens, start_index)
            node = declaration_node
            token_count = declaration_token_count
        case .EQUALS:
            assignment_node, assignemnt_token_count := parse_assignment_statement(tokens, start_index)
            node = assignment_node
            token_count = assignemnt_token_count
        case .OPENING_BRACKET:
            exit_node, exit_token_count := parse_exit_statement(tokens, start_index)
            node = exit_node
            token_count = exit_token_count
        case:
            fmt.println("Invalid statement")
            os.exit(1)
        }
    case:
        fmt.println("Invalid statement")
        os.exit(1)
    }

    return
}

parse_scope :: proc(tokens: [dynamic]token, start_index: int) -> (node: ast_node, token_count: int)
{
    node.type = .SCOPE

    // opening squiggly bracket
    token_count += 1

    for start_index + token_count < len(tokens)
    {
        if tokens[start_index + token_count].type == .CLOSING_SQUIGGLY_BRACKET
        {
            // closing squiggly bracket
            token_count += 1

            return
        }

        child_node, child_token_count := parse_statement(tokens, start_index + token_count)

        append(&node.children, child_node)
        token_count += child_token_count
    }

    fmt.println("Scope never ends")
    os.exit(1)
}

parse_declaration_statement :: proc(tokens: [dynamic]token, start_index: int) -> (node: ast_node, token_count: int)
{
    if start_index + 3 >= len(tokens)
    {
        fmt.println("Invalid statement, end of file encountered")
        os.exit(1)
    }

    node.type = .DECLARATION_STATEMENT

    lhs_node := ast_node { type = .IDENTIFIER, value = tokens[start_index].value }
    append(&node.children, lhs_node)
    token_count += 1

    if tokens[start_index + 1].type != .COLON || tokens[start_index + 2].type != .EQUALS
    {
        fmt.println("Invalid statement")
        os.exit(1)
    }

    // colon
    token_count += 1

    // equals
    token_count += 1

    rhs_node, rhs_token_count := parse_term(tokens, start_index + token_count)
    append(&node.children, rhs_node)
    token_count += rhs_token_count

    return
}

parse_assignment_statement :: proc(tokens: [dynamic]token, start_index: int) -> (node: ast_node, token_count: int)
{
    if start_index + 2 >= len(tokens)
    {
        fmt.println("Invalid statement, end of file encountered")
        os.exit(1)
    }

    node.type = .ASSIGNMENT_STATEMENT

    lhs_node := ast_node { type = .IDENTIFIER, value = tokens[start_index].value }
    append(&node.children, lhs_node)
    token_count += 1

    if tokens[start_index + 1].type != .EQUALS
    {
        fmt.println("Invalid statement")
        os.exit(1)
    }

    // equals
    token_count += 1

    rhs_node, rhs_token_count := parse_term(tokens, start_index + token_count)
    append(&node.children, rhs_node)
    token_count += rhs_token_count

    return
}

parse_exit_statement :: proc(tokens: [dynamic]token, start_index: int) -> (node: ast_node, token_count: int)
{
    if start_index + 3 >= len(tokens)
    {
        fmt.println("Invalid statement, end of file encountered")
        os.exit(1)
    }

    if tokens[start_index + 1].type != .OPENING_BRACKET || tokens[start_index + 3].type != .CLOSING_BRACKET
    {
        fmt.println("Invalid statement")
        os.exit(1)
    }

    node.type = .EXIT_STATEMENT

    // identifier, opening bracket
    token_count += 2

    param_node, param_token_count := parse_term(tokens, start_index + 2)
    append(&node.children, param_node)
    token_count += param_token_count

    // closing bracket
    token_count += 1

    return
}

parse_term :: proc(tokens: [dynamic]token, start_index: int) -> (node: ast_node, token_count: int)
{
    node.type = .TERM

    child_node := ast_node { value = tokens[start_index].value }

    #partial switch tokens[start_index].type
    {
    case .IDENTIFIER:
        child_node.type = .IDENTIFIER
    case .INTEGER_LITERAL:
        child_node.type = .INTEGER_LITERAL
    case:
        fmt.println("Invalid term")
        os.exit(1)
    }

    append(&node.children, child_node)

    token_count += 1

    return
}
