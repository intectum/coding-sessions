package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"

parsing_context :: struct
{
    return_value_required: bool
}

primary_type :: enum
{
    none,
    lhs,
    rhs,
    type
}

parse_module :: proc(stream: ^token_stream) -> (nodes: [dynamic]ast_node, ok: bool)
{
    ctx: parsing_context = { true }

    for stream.next_index < len(stream.tokens)
    {
        statement_node := parse_statement(stream, &ctx) or_return
        append(&nodes, statement_node)
    }

    return nodes, true
}

parse_statement :: proc(stream: ^token_stream, ctx: ^parsing_context) -> (node: ast_node, ok: bool)
{
    if peek_token(stream).type == .keyword
    {
        if peek_token(stream).value == "if"
        {
            return parse_if(stream, ctx)
        }
        else if peek_token(stream).value == "for"
        {
            return parse_for(stream, ctx)
        }
        else if peek_token(stream).value == "return"
        {
            return parse_return(stream, ctx)
        }
    }

    return parse_scope_or_assignment_or_rhs_expression(stream, ctx)
}

parse_if :: proc(stream: ^token_stream, ctx: ^parsing_context) -> (node: ast_node, ok: bool)
{
    node.type = .if_
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.keyword, "if") or_return

    if_brackets := false
    if peek_token(stream).type == .opening_bracket
    {
        next_token(stream, .opening_bracket) or_return
        if_brackets = true
    }

    expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, expression_node)

    if if_brackets
    {
        next_token(stream, .closing_bracket) or_return
    }

    statement_node := parse_statement(stream, ctx) or_return
    append(&node.children, statement_node)

    for peek_token(stream).value == "else" && peek_token(stream, 1).value == "if"
    {
        next_token(stream, token_type.keyword, "else") or_return
        next_token(stream, token_type.keyword, "if") or_return

        else_if_brackets := false
        if peek_token(stream).type == .opening_bracket
        {
            next_token(stream, .opening_bracket) or_return
            else_if_brackets = true
        }

        else_if_expression_node := parse_rhs_expression(stream) or_return
        append(&node.children, else_if_expression_node)

        if else_if_brackets
        {
            next_token(stream, .closing_bracket) or_return
        }

        else_if_statement_node := parse_statement(stream, ctx) or_return
        append(&node.children, else_if_statement_node)
    }

    if peek_token(stream).value == "else"
    {
        next_token(stream, token_type.keyword, "else") or_return

        else_statement_node := parse_statement(stream, ctx) or_return
        append(&node.children, else_statement_node)
    }

    return node, true
}

parse_for :: proc(stream: ^token_stream, ctx: ^parsing_context) -> (node: ast_node, ok: bool)
{
    node.type = .for_
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.keyword, "for") or_return

    brackets := false
    if peek_token(stream).type == .opening_bracket
    {
        next_token(stream, .opening_bracket) or_return
        brackets = true
    }

    pre_statement_stream := stream^
    pre_statement_node, pre_statement_ok := parse_statement(&pre_statement_stream, ctx)

    _, statement := slice.linear_search(statement_node_types, pre_statement_node.type)
    if pre_statement_ok && statement
    {
        stream^ = pre_statement_stream
        append(&node.children, pre_statement_node)

        next_token(stream, .comma) or_return
    }

    expression_node := parse_rhs_expression(stream) or_return
    append(&node.children, expression_node)

    if peek_token(stream).type == .comma
    {
        next_token(stream, .comma) or_return

        post_statement_node := parse_statement(stream, ctx) or_return
        append(&node.children, post_statement_node)
    }

    if brackets
    {
        next_token(stream, .closing_bracket) or_return
    }

    statement_node := parse_statement(stream, ctx) or_return
    append(&node.children, statement_node)

    return node, true
}

parse_return :: proc(stream: ^token_stream, ctx: ^parsing_context) -> (node: ast_node, ok: bool)
{
    node.type = .return_
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.keyword, "return") or_return

    if ctx.return_value_required
    {
        expression_node := parse_rhs_expression(stream) or_return
        append(&node.children, expression_node)
    }

    return node, true
}

parse_scope_or_assignment_or_rhs_expression :: proc(stream: ^token_stream, ctx: ^parsing_context) -> (node: ast_node, ok: bool)
{
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

parse_scope :: proc(stream: ^token_stream, ctx: ^parsing_context) -> (node: ast_node, ok: bool)
{
    node.type = .scope
    node.file_info = peek_token(stream).file_info

    next_token(stream, .opening_curly_bracket) or_return

    for stream.next_index < len(stream.tokens)
    {
        if peek_token(stream).type == .closing_curly_bracket
        {
            next_token(stream, .closing_curly_bracket) or_return
            return node, true
        }

        statement_node := parse_statement(stream, ctx) or_return
        append(&node.children, statement_node)
    }

    stream.error = "Scope never ends"
    return {}, false
}

parse_assignment :: proc(stream: ^token_stream, ctx: ^parsing_context) -> (node: ast_node, ok: bool)
{
    node.type = .assignment
    node.file_info = peek_token(stream).file_info

    lhs_node := parse_lhs_expression(stream) or_return
    append(&node.children, lhs_node)

    lhs_type_node := get_type(&lhs_node)
    if !is_member(&lhs_node) && lhs_type_node != nil && lhs_type_node.value == "[procedure]"
    {
        ctx.return_value_required = len(lhs_type_node.children) == 2
    }

    token := peek_token(stream)
    _, assignment_operator := slice.linear_search(assignment_operator_token_types, token.type)
    if assignment_operator
    {
        next_token(stream, token.type) or_return

        operator_node := ast_node { type = to_ast_node_type(token.type), file_info = token.file_info }
        append(&node.children, operator_node)

        statement_node := parse_statement(stream, ctx) or_return
        append(&node.children, statement_node)
    }

    return node, true
}

parse_lhs_expression :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node = parse_primary(stream, .lhs) or_return

    if peek_token(stream).type == .colon
    {
        next_token(stream, .colon) or_return

        type_node := parse_primary(stream, .type) or_return

        if peek_token(stream).type == .at
        {
            next_token(stream, .at) or_return

            type_node.allocator = (next_token(stream, .identifier) or_return).value
        }

        append(&node.children, type_node)
    }

    return node, true
}

// Based on https://en.wikipedia.org/wiki/Operator-precedence_parser#Pseudocode
parse_rhs_expression :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    first_primary_node := parse_primary(stream, .rhs) or_return
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
        rhs := parse_primary(stream, .rhs) or_return
        lookahead = peek_token(stream)
        for is_binary_operator(lookahead) && binary_operator_precedence(lookahead) > binary_operator_precedence(op)
        {
            // NOTE: Need to re-check pseudo code for min_precedence if adding support for right-associative operators
            rhs = parse_rhs_expression_1(stream, rhs, binary_operator_precedence(op) + 1) or_return
            lookahead = peek_token(stream)
        }

        new_lhs := ast_node { type = to_ast_node_type(op.type) }
        new_lhs.file_info = op.file_info

        append(&new_lhs.children, final_lhs)
        append(&new_lhs.children, rhs)
        final_lhs = new_lhs
    }

    return final_lhs, true
}

parse_primary :: proc(stream: ^token_stream, type: primary_type) -> (node: ast_node, ok: bool)
{
    node.file_info = peek_token(stream).file_info

    #partial switch peek_token(stream).type
    {
    case .directive:
        if type == .lhs
        {
            stream.error = "A left-hand-side primary cannot contain a directive"
            return {}, false
        }

        directive := (next_token(stream, .directive) or_return).value

        node = parse_primary(stream, type) or_return
        node.directive = directive
    case .hat:
        if type == .lhs
        {
            stream.error = "A left-hand-side primary cannot be referenced"
            return {}, false
        }

        next_token(stream, .hat) or_return

        node.type = .reference

        primary_node := parse_primary(stream, type) or_return
        append(&node.children, primary_node)
    case .minus:
        if type != .rhs
        {
            stream.error = "Only a right-hand-side primary can be negated"
            return {}, false
        }

        next_token(stream, .minus) or_return

        node.type = .negate

        primary_node := parse_primary(stream, type) or_return
        append(&node.children, primary_node)
    case .exclamation:
        if type != .rhs
        {
            stream.error = "Only a right-hand-side primary can be inverted"
            return {}, false
        }

        next_token(stream, .exclamation) or_return

        node.type = .not

        primary_node := parse_primary(stream, type) or_return
        append(&node.children, primary_node)
    case .opening_bracket:
        if type != .rhs
        {
            stream.error = "Only a right-hand-side primary can contain a sub-expression"
            return {}, false
        }

        next_token(stream, .opening_bracket) or_return

        node = parse_rhs_expression(stream) or_return

        next_token(stream, .closing_bracket) or_return
    case .identifier:
        node = parse_identifier(stream) or_return

        if type == .type
        {
            node.type = .type
        }
    case .keyword:
        if type == .lhs
        {
            stream.error = "A left-hand-side primary cannot contain a type literal"
            return {}, false
        }

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
    case .string_:
        if type != .rhs
        {
            stream.error = "Only a right-hand-side primary can contain a string literal"
            return {}, false
        }

        node.type = .string_
        node.value = (next_token(stream, .string_) or_return).value
    case .number:
        if type != .rhs
        {
            stream.error = "Only a right-hand-side primary can contain a number literal"
            return {}, false
        }

        node.type = .number
        node.value = (next_token(stream, .number) or_return).value
    case .boolean:
        if type != .rhs
        {
            stream.error = "Only a right-hand-side primary can contain a boolean literal"
            return {}, false
        }

        node.type = .boolean
        node.value = (next_token(stream, .boolean) or_return).value
    case .opening_curly_bracket:
        node = parse_compound_literal(stream) or_return
    case .nil_:
        if type != .rhs
        {
            stream.error = "Only a right-hand-side primary can contain a nil"
            return {}, false
        }

        node.type = .nil_
        node.value = (next_token(stream, .nil_) or_return).value
    case:
        stream.error = "Failed to parse primary"
        return {}, false
    }

    found_suffix := true
    for found_suffix
    {
        #partial switch peek_token(stream).type
        {
        case .hat:
            if type == .type
            {
                stream.error = "A type primary cannot be dereferenced"
                return {}, false
            }

            next_token(stream, .hat) or_return

            child_node := node

            node = {
                type = .dereference,
                file_info = child_node.file_info
            }

            append(&node.children, child_node)
        case .opening_square_bracket:
            next_token(stream, .opening_square_bracket) or_return

            child_node := node

            node = {
                type = type == .type ? .type : .index,
                value = type == .type ? "[slice]" : "",
                file_info = child_node.file_info
            }

            append(&node.children, child_node)

            if type == .type
            {
                if peek_token(stream).type == .number
                {
                    node.value = "[array]"

                    number_node := ast_node {
                        type = .number,
                        value = (next_token(stream, .number) or_return).value,
                        file_info = child_node.file_info
                    }
                    append(&node.children, number_node)
                }
            }
            else
            {
                if peek_token(stream).type == .colon
                {
                    append(&node.children, ast_node { type = .nil_ })
                }
                else
                {
                    start_expression_node := parse_rhs_expression(stream) or_return
                    append(&node.children, start_expression_node)
                }

                if peek_token(stream).type == .colon
                {
                    next_token(stream, .colon) or_return

                    if peek_token(stream).type == .closing_square_bracket
                    {
                        append(&node.children, ast_node { type = .nil_ })
                    }
                    else
                    {
                        end_expression_node := parse_rhs_expression(stream) or_return
                        append(&node.children, end_expression_node)
                    }
                }
            }

            next_token(stream, .closing_square_bracket) or_return
        case .period:
            next_token(stream, .period) or_return

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
                stream.error = "Only a right-hand-side primary can contain a call"
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

parse_call :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .call
    node.file_info = peek_token(stream).file_info

    next_token(stream, .opening_bracket) or_return

    for peek_token(stream).type != .closing_bracket
    {
        param_node := parse_rhs_expression(stream) or_return
        append(&node.children, param_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .closing_bracket
        {
            next_token(stream, .comma) or_return
        }
    }

    next_token(stream, .closing_bracket) or_return

    return node, true
}

parse_compound_literal :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    dummy_ctx: parsing_context

    node.type = .compound_literal
    node.file_info = peek_token(stream).file_info

    next_token(stream, .opening_curly_bracket) or_return

    for peek_token(stream).type != .closing_curly_bracket
    {
        member_node := parse_assignment(stream, &dummy_ctx) or_return
        append(&node.children, member_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .closing_curly_bracket
        {
            next_token(stream, .comma) or_return
        }
    }

    next_token(stream, .closing_curly_bracket) or_return

    return node, true
}

parse_struct_type :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .type
    node.value = "[struct]"
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.keyword, "struct") or_return

    next_token(stream, .opening_curly_bracket) or_return

    for peek_token(stream).type != .closing_curly_bracket
    {
        member_node := parse_identifier(stream) or_return

        next_token(stream, .colon) or_return

        member_type_node := parse_primary(stream, .type) or_return
        append(&member_node.children, member_type_node)

        append(&node.children, member_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .closing_curly_bracket
        {
            next_token(stream, .comma) or_return
        }
    }

    next_token(stream, .closing_curly_bracket) or_return

    return node, true
}

parse_procedure_type :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    node.type = .type
    node.value = "[procedure]"
    node.file_info = peek_token(stream).file_info

    next_token(stream, token_type.keyword, "proc") or_return

    next_token(stream, .opening_bracket) or_return

    params_type_node := ast_node { type = .type, value = "[parameters]" }

    for peek_token(stream).type != .closing_bracket
    {
        param_node := parse_identifier(stream) or_return

        next_token(stream, .colon) or_return

        param_type_node := parse_primary(stream, .type) or_return
        append(&param_node.children, param_type_node)

        append(&params_type_node.children, param_node)

        // TODO allows comma at end of params
        if peek_token(stream).type != .closing_bracket
        {
            next_token(stream, .comma) or_return
        }
    }

    append(&node.children, params_type_node)

    next_token(stream, .closing_bracket) or_return

    if peek_token(stream).type == .dash_greater_than
    {
        next_token(stream, .dash_greater_than) or_return

        return_type_node := parse_primary(stream, .type) or_return
        append(&node.children, return_type_node)
    }

    return node, true
}

parse_identifier :: proc(stream: ^token_stream) -> (node: ast_node, ok: bool)
{
    token := next_token(stream, .identifier) or_return
    node = ast_node {
        type = .identifier,
        value = token.value,
        file_info = token.file_info
    }

    return node, true
}

is_binary_operator :: proc(token: token) -> bool
{
    _, binary_operator := slice.linear_search(binary_operator_token_types, token.type)
    return binary_operator
}

binary_operator_precedence :: proc(token: token) -> int
{
    #partial switch token.type
    {
    case .pipe_pipe:
        return 1
    case .ampersand_ampersand:
        return 2
    case .equals_equals, .exclamation_equals, .opening_angle_bracket, .closing_angle_bracket, .opening_angle_bracket_equals, .closing_angle_bracket_equals:
        return 3
    case .plus, .minus:
        return 4
    case .asterisk, .backslash, .percent:
        return 5
    }

    assert(false, "Unsupported binary operator")
    return 0
}

to_ast_node_type :: proc(token_type: token_type) -> ast_node_type
{
    #partial switch token_type
    {
    case .equals:
        return .assign
    case .equals_equals:
        return .equal
    case .exclamation_equals:
        return .not_equal
    case .opening_angle_bracket:
        return .less_than
    case .closing_angle_bracket:
        return .greater_than
    case .opening_angle_bracket_equals:
        return .less_than_or_equal
    case .closing_angle_bracket_equals:
        return .greater_than_or_equal
    case .plus:
        return .add
    case .plus_equals:
        return .add_assign
    case .minus:
        return .subtract
    case .minus_equals:
        return .subtract_assign
    case .asterisk:
        return .multiply
    case .asterisk_equals:
        return .multiply_assign
    case .backslash:
        return .divide
    case .backslash_equals:
        return .divide_assign
    case .percent:
        return .modulo
    case .percent_equals:
        return .modulo_assign
    case .ampersand_ampersand:
        return .and
    case .pipe_pipe:
        return .or
    }

    assert(false, "Unsupported ast node type")
    return .equal
}
