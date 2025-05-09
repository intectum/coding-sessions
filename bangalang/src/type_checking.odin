package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:strconv"

procedure :: struct
{
    param_data_types: [dynamic]data_type,
    return_data_type: data_type,
    directive: string
}

type_checking_context :: struct
{
    procedures: map[string]procedure,
    procedure: procedure,

    variable_data_types: map[string]data_type
}

numerical_data_types: []string = { "cint", "f32", "f64", "i8", "i16", "i32", "i64", "number" }
float_data_types: []string = { "f32", "f64" }
signed_integer_data_types: []string = { "cint", "i8", "i16", "i32", "i64" }

type_check_program :: proc(nodes: [dynamic]ast_node) -> (ok: bool = true)
{
    ctx: type_checking_context

    print: procedure
    append(&print.param_data_types, data_type { "string", 1, false })
    ctx.procedures["print"] = print

    printb: procedure
    append(&printb.param_data_types, data_type { "i8", 1000000, true })
    append(&printb.param_data_types, data_type { "i64", 1, false })
    ctx.procedures["printb"] = printb

    exit: procedure
    append(&exit.param_data_types, data_type { "i64", 1, false })
    ctx.procedures["exit"] = exit

    for node in nodes
    {
        if node.type == .PROCEDURE
        {
            name: string
            procedure := procedure { return_data_type = node.data_type, directive = node.directive }
            for child_node, index in node.children
            {
                if index == 0
                {
                    name = child_node.value
                }
                else if node.children[index].type == .IDENTIFIER
                {
                    append(&procedure.param_data_types, child_node.data_type)
                }
            }

            ctx.procedures[name] = procedure
        }
    }

    for &node in nodes
    {
        if node.type != .PROCEDURE
        {
            statement_ok := type_check_statement(&node, &ctx)
            if !statement_ok
            {
                ok = false
            }
        }
    }

    for &node in nodes
    {
        if node.type == .PROCEDURE
        {
            procedure_ok := type_check_procedure(&node, &ctx)
            if !procedure_ok
            {
                ok = false
            }
        }
    }

    return
}

type_check_procedure :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    procedure_ctx := copy_type_checking_context(ctx^)
    procedure_ctx.procedure = procedure_ctx.procedures[name_node.value]

    for child_index < len(node.children) && node.children[child_index].type == .IDENTIFIER
    {
        param_node := node.children[child_index]
        child_index += 1

        procedure_ctx.variable_data_types[param_node.value] = param_node.data_type
    }

    if node.directive == "#extern" && child_index < len(node.children)
    {
        fmt.println("Failed to type check procedure")
        fmt.printfln("#extern procedure '%s' cannot have a procedure body at line %i, column %i", name_node.value, node.line_number, node.column_number)
        ok = false
    }
    else if node.directive != "#extern" && child_index >= len(node.children)
    {
        fmt.println("Failed to type check procedure")
        fmt.printfln("Procedure '%s' must have a procedure body at line %i, column %i", name_node.value, node.line_number, node.column_number)
        ok = false
    }

    if child_index < len(node.children)
    {
        statement_node := &node.children[child_index]
        child_index += 1

        statement_ok := type_check_statement(statement_node, &procedure_ctx)
        if !statement_ok
        {
            ok = false
        }
    }

    return
}

type_check_statement :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    #partial switch node.type
    {
    case .IF:
        ok = type_check_if(node, ctx)
    case .FOR:
        ok = type_check_for(node, ctx)
    case .SCOPE:
        ok = type_check_scope(node, ctx)
    case .DECLARATION:
        ok = type_check_declaration(node, ctx)
    case .ASSIGNMENT:
        ok = type_check_assignment(node, ctx)
    case .RETURN:
        ok = type_check_return(node, ctx)
    case .CALL:
        ok = type_check_call(node, ctx)
    case:
        assert(false, "Failed to type check statement")
    }

    return
}

type_check_if :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    child_index := 0
    expression_node := &node.children[child_index]
    child_index += 1

    expression_ok := type_check_expression(expression_node, ctx, { "bool", 1, false })
    if !expression_ok
    {
        ok = false
    }

    statement_node := &node.children[child_index]
    child_index += 1

    statement_ok := type_check_statement(statement_node, ctx)
    if !statement_ok
    {
        ok = false
    }

    for child_index + 1 < len(node.children)
    {
        else_if_expression_ok := type_check_expression(&node.children[child_index], ctx, { "bool", 1, false })
        if !else_if_expression_ok
        {
            ok = false
        }
        child_index += 1

        else_if_statement_ok := type_check_statement(&node.children[child_index], ctx)
        if !else_if_statement_ok
        {
            ok = false
        }
        child_index += 1
    }

    if child_index < len(node.children)
    {
        else_statement_ok := type_check_statement(&node.children[child_index], ctx)
        if !else_statement_ok
        {
            ok = false
        }
        child_index += 1
    }

    return
}

type_check_for :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    for_ctx := copy_type_checking_context(ctx^, true)

    child_index := 0
    child_node := &node.children[child_index]
    child_index += 1

    if child_node.type == .DECLARATION
    {
        declaration_ok := type_check_declaration(child_node, &for_ctx)
        if !declaration_ok
        {
            ok = false
        }

        child_node = &node.children[child_index]
        child_index += 1
    }

    expression_ok := type_check_expression(child_node, &for_ctx, { "bool", 1, false })
    if !expression_ok
    {
        ok = false
    }

    child_node = &node.children[child_index]
    child_index += 1

    if child_node.type == .ASSIGNMENT
    {
        assignment_ok := type_check_assignment(child_node, &for_ctx)
        if !assignment_ok
        {
            ok = false
        }

        child_node = &node.children[child_index]
        child_index += 1
    }

    statement_ok := type_check_statement(child_node, &for_ctx)
    if !statement_ok
    {
        ok = false
    }

    return
}

type_check_scope :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    scope_ctx := copy_type_checking_context(ctx^, true)

    for &child_node in node.children
    {
        statement_ok := type_check_statement(&child_node, &scope_ctx)
        if !statement_ok
        {
            ok = false
        }
    }

    return
}

type_check_declaration :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    lhs_node := &node.children[0]

    if lhs_node.value in ctx.variable_data_types
    {
        fmt.println("Failed to type check declaration")
        fmt.printfln("Duplicate identifier '%s' at line %i, column %i", lhs_node.value, lhs_node.line_number, lhs_node.column_number)
        ok = false
    }

    if len(node.children) > 1
    {
        rhs_node := &node.children[1]

        rhs_ok := type_check_expression(rhs_node, ctx, lhs_node.data_type)
        if !rhs_ok
        {
            ok = false
        }

        if lhs_node.data_type.name == ""
        {
            lhs_node.data_type = rhs_node.data_type
        }
    }

    if lhs_node.data_type.name == ""
    {
        fmt.println("Failed to type check declaration")
        fmt.printfln("Could not determine type of '%s' at line %i, column %i", lhs_node.value, lhs_node.line_number, lhs_node.column_number)
        ok = false
    }

    ctx.variable_data_types[lhs_node.value] = lhs_node.data_type

    return
}

type_check_assignment :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    lhs_node := &node.children[0]
    rhs_node := &node.children[1]

    lhs_ok := type_check_variable(lhs_node, ctx)
    if !lhs_ok
    {
        ok = false
    }

    rhs_ok := type_check_expression(rhs_node, ctx, lhs_node.data_type)
    if !rhs_ok
    {
        ok = false
    }

    return
}

type_check_return :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    expression_node := &node.children[0]

    expression_ok := type_check_expression(expression_node, ctx, ctx.procedure.return_data_type)
    if !expression_ok
    {
        ok = false
    }

    return
}

type_check_expression :: proc(node: ^ast_node, ctx: ^type_checking_context, expected_data_type: data_type) -> (ok: bool = true)
{
    expression_1_ok := type_check_expression_1(node, ctx)
    if !expression_1_ok
    {
        ok = false
    }

    data_types := []data_type { node.data_type, expected_data_type }
    data_type, coerce_ok := coerce_type(data_types)
    if !coerce_ok
    {
        data_type_names: [dynamic]string
        for data_type, index in data_types
        {
            if data_type.name != ""
            {
                append(&data_type_names, data_type_name(data_type))
            }
        }
        fmt.println("Failed to type check expression")
        fmt.printfln("Incompatible types %s at line %i, column %i", data_type_names, node.line_number, node.column_number)
        ok = false
    }

    if node.data_type.name == "number"
    {
        propagate_data_type(node, data_type)
    }
    else
    {
        node.data_type = data_type
    }

    return
}

type_check_expression_1 :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    if node.type != .EQUAL && node.type != .NOT_EQUAL && node.type != .LESS_THAN && node.type != .GREATER_THAN && node.type != .LESS_THAN_OR_EQUAL && node.type != .GREATER_THAN_OR_EQUAL && node.type != .ADD && node.type != .SUBTRACT && node.type != .MULTIPLY && node.type != .DIVIDE
    {
        ok = type_check_primary(node, ctx)
        return
    }

    lhs_node := &node.children[0]
    rhs_node := &node.children[1]

    lhs_ok := type_check_expression_1(lhs_node, ctx)
    if !lhs_ok
    {
        ok = false
    }

    rhs_ok := type_check_expression_1(rhs_node, ctx)
    if !rhs_ok
    {
        ok = false
    }

    data_types := []data_type { lhs_node.data_type, rhs_node.data_type }
    data_type, coerce_ok := coerce_type(data_types)
    if !coerce_ok
    {
        data_type_names: [dynamic]string
        for data_type, index in data_types
        {
            if data_type.name != ""
            {
                append(&data_type_names, data_type_name(data_type))
            }
        }
        fmt.println("Failed to type check expression")
        fmt.printfln("Incompatible types %s at line %i, column %i", data_type_names, node.line_number, node.column_number)
        ok = false
    }

    _, comparison_operator := slice.linear_search(comparison_operators, node.type)
    if comparison_operator
    {
        node.data_type = { "bool", 1, false }
        if data_type.name == "number"
        {
            propagate_data_type(lhs_node, { "f64", 1, false })
            propagate_data_type(rhs_node, { "f64", 1, false })
        }
        else
        {
            propagate_data_type(lhs_node, data_type)
            propagate_data_type(rhs_node, data_type)
        }
    }
    else
    {
        node.data_type = data_type
        lhs_node.data_type = data_type
        rhs_node.data_type = data_type
    }

    _, numerical_data_type := slice.linear_search(numerical_data_types, data_type.name)
    if data_type.length > 1
    {
        fmt.println("Failed to type check expression")
        fmt.printfln("Invalid type '%s' at line %i, column %i", data_type_name(node.data_type), node.line_number, node.column_number)
        ok = false
    }
    else if data_type.name == "bool" && node.type != .EQUAL && node.type != .NOT_EQUAL
    {
        fmt.println("Failed to type check expression")
        fmt.printfln("Invalid type '%s' at line %i, column %i", data_type_name(node.data_type), node.line_number, node.column_number)
        ok = false
    }

    return
}

type_check_primary :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    #partial switch node.type
    {
    case .REFERENCE:
        primary_ok := type_check_primary(&node.children[0], ctx)
        if !primary_ok
        {
            ok = false
        }

        node.data_type = node.children[0].data_type
        node.data_type.is_reference = true

        if node.children[0].data_type.is_reference
        {
            fmt.println("Failed to type check primary")
            fmt.printfln("Invalid type '%s' at line %i, column %i", data_type_name(node.data_type), node.line_number, node.column_number)
            ok = false
        }
    case .NEGATE:
        primary_ok := type_check_primary(&node.children[0], ctx)
        if !primary_ok
        {
            ok = false
        }

        node.data_type = node.children[0].data_type

        if node.data_type.is_reference && node.data_type.length > 1
        {
            fmt.println("Failed to type check primary")
            fmt.printfln("Invalid type '%s' at line %i, column %i", data_type_name(node.data_type), node.line_number, node.column_number)
            ok = false
        }
    case .DEREFERENCE:
        primary_ok := type_check_primary(&node.children[0], ctx)
        if !primary_ok
        {
            ok = false
        }

        node.data_type = node.children[0].data_type
        node.data_type.is_reference = false

        if !node.children[0].data_type.is_reference
        {
            fmt.println("Failed to type check primary")
            fmt.printfln("Invalid type '%s' at line %i, column %i", data_type_name(node.data_type), node.line_number, node.column_number)
            ok = false
        }
    case .INDEX:
        primary_ok := type_check_primary(&node.children[0], ctx)
        if !primary_ok
        {
            ok = false
        }

        identifier := node.children[0].value

        if node.children[0].data_type.is_reference
        {
            child_node := node.children[0]

            node.children[0] = {
                type = .DEREFERENCE,
                line_number = child_node.line_number,
                column_number = child_node.column_number
            }

            node.children[0].data_type = child_node.data_type
            node.children[0].data_type.is_reference = false

            append(&node.children[0].children, child_node)
        }

        node.data_type = node.children[0].data_type
        node.data_type.length = 1

        if node.data_index >= node.children[0].data_type.length
        {
            fmt.println("Failed to type check primary")
            fmt.printfln("Index %i out of bounds of '%s' at line %i, column %i", node.data_index, identifier, node.line_number, node.column_number)
            ok = false
        }
    case .CALL:
        ok = type_check_call(node, ctx)
    case .IDENTIFIER:
        node.data_type = ctx.variable_data_types[node.value]

        if !(node.value in ctx.variable_data_types)
        {
            fmt.println("Failed to type check primary")
            fmt.printfln("Undeclared identifier '%s' at line %i, column %i", node.value, node.line_number, node.column_number)
            ok = false
        }
    case .STRING:
        node.data_type = { "string", 1, false }
    case .CSTRING:
        node.data_type = { "cstring", 1, false }
    case .NUMBER:
        node.data_type = { "number", 1, false }
    case .BOOLEAN:
        node.data_type = { "bool", 1, false }
    case:
        ok = type_check_expression_1(node, ctx)
    }

    return
}

type_check_call :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    if !(name_node.value in ctx.procedures)
    {
        fmt.println("Failed to type check call")
        fmt.printfln("Undeclared identifier '%s' at line %i, column %i", name_node.value, name_node.line_number, name_node.column_number)
        ok = false
    }

    procedure := ctx.procedures[name_node.value]

    if len(procedure.param_data_types) != len(node.children) - 1
    {
        fmt.println("Failed to type check call")
        fmt.printfln("Wrong number of parameters at line %i, column %i", node.line_number, node.column_number)
        fmt.printfln("Expected: %i", len(procedure.param_data_types))
        fmt.printfln("Found: %i", len(node.children) - 1)
        ok = false
    }

    for child_index < len(node.children)
    {
        param_data_type := procedure.param_data_types[child_index - 1]

        param_node := &node.children[child_index]
        child_index += 1

        param_ok := type_check_expression(param_node, ctx, param_data_type)
        if !param_ok
        {
            ok = false
        }
    }

    node.directive = procedure.directive
    node.data_type = procedure.return_data_type

    return
}

type_check_variable :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    identifier_node := node.type == .INDEX ? &node.children[0] : node

    if !(identifier_node.value in ctx.variable_data_types)
    {
        fmt.println("Failed to type check variable")
        fmt.printfln("Undeclared identifier '%s' at line %i, column %i", identifier_node.value, node.line_number, node.column_number)
        ok = false
    }

    identifier_node.data_type = ctx.variable_data_types[identifier_node.value]
    identifier_node_copy := identifier_node^

    if node.type == .INDEX
    {
        if identifier_node_copy.data_type.is_reference
        {
            node.children[0] = {
                type = .DEREFERENCE,
                line_number = identifier_node_copy.line_number,
                column_number = identifier_node_copy.column_number
            }

            node.children[0].data_type = identifier_node_copy.data_type
            node.children[0].data_type.is_reference = false

            append(&node.children[0].children, identifier_node_copy)
        }

        node.data_type = identifier_node.data_type
        node.data_type.length = 1
    }

    if ok && node.data_index >= identifier_node_copy.data_type.length
    {
        fmt.println("Failed to type check variable")
        fmt.printfln("Index %i out of bounds of '%s' at line %i, column %i", node.data_index, identifier_node_copy.value, node.line_number, node.column_number)
        ok = false
    }

    return
}

copy_type_checking_context := proc(ctx: type_checking_context, inline := false) -> type_checking_context
{
    ctx_copy: type_checking_context
    for key in ctx.procedures
    {
        ctx_copy.procedures[key] = ctx.procedures[key]
    }
    ctx_copy.procedure = ctx.procedure

    if inline
    {
        for key in ctx.variable_data_types
        {
            ctx_copy.variable_data_types[key] = ctx.variable_data_types[key]
        }
    }

    return ctx_copy
}

coerce_type :: proc(data_types: []data_type) -> (data_type, bool)
{
    coerced_data_type := data_types[0]
    for data_type in data_types[1:]
    {
        if data_type.name == ""
        {
            continue
        }

        if coerced_data_type.name == ""
        {
            coerced_data_type = data_type
            continue
        }

        if data_type.length != coerced_data_type.length
        {
            return {}, false
        }

        if data_type.is_reference != coerced_data_type.is_reference
        {
            return {}, false
        }

        if data_type.name != coerced_data_type.name
        {
            _, coerced_numerical_data_type := slice.linear_search(numerical_data_types, coerced_data_type.name)
            if data_type.name == "number" && coerced_numerical_data_type
            {
                continue
            }

            _, numerical_data_type := slice.linear_search(numerical_data_types, data_type.name)
            if coerced_data_type.name == "number" && numerical_data_type
            {
                coerced_data_type = data_type
                continue
            }

            return {}, false
        }
    }

    if coerced_data_type.name != ""
    {
        return coerced_data_type, true
    }

    return {}, false
}

data_type_name :: proc(data_type: data_type) -> string
{
    name := data_type.name

    if data_type.is_reference
    {
        name = strings.concatenate({ "^", name })
    }

    if data_type.length > 1
    {
        buf: [8]byte
        name = strings.concatenate({ name, "[", strconv.itoa(buf[:], data_type.length), "]" })
    }

    return name
}

propagate_data_type :: proc(node: ^ast_node, data_type: data_type)
{
    if node.data_type.name != "number"
    {
        return
    }

    node.data_type = data_type
    for &child_node in node.children
    {
        propagate_data_type(&child_node, data_type)
    }
}
