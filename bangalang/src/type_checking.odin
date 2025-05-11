package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:strconv"

type_checking_context :: struct
{
    identifier_data_types: map[string]data_type,
    procedure_data_type: data_type
}

numerical_data_types: []string = { "cint", "f32", "f64", "i8", "i16", "i32", "i64", "number" }
float_data_types: []string = { "f32", "f64" }
signed_integer_data_types: []string = { "cint", "i8", "i16", "i32", "i64" }

type_check_program :: proc(nodes: [dynamic]ast_node) -> (ok: bool = true)
{
    ctx: type_checking_context

    print := data_type { name = "procedure", length = 1 }
    append(&print.children, data_type { name = "parameters", length = 1 })
    append(&print.children[0].children, data_type { name = "string", length = 1 })
    ctx.identifier_data_types["print"] = print

    printb := data_type { name = "procedure", length = 1 }
    append(&printb.children, data_type { name = "parameters", length = 1 })
    append(&printb.children[0].children, data_type { name = "i8", directive = "#boundless", is_reference = true })
    append(&printb.children[0].children, data_type { name = "i64", length = 1 })
    ctx.identifier_data_types["printb"] = printb

    clone := data_type { name = "procedure", length = 1 }
    append(&clone.children, data_type { name = "parameters", length = 1 })
    append(&clone.children[0].children, data_type { name = "procedure", length = 1 })
    append(&clone.children[0].children[0].children, data_type { name = "parameters", length = 1 })
    append(&clone.children, data_type { name = "i64", length = 1 })
    ctx.identifier_data_types["clone"] = clone

    exit := data_type { name = "procedure", length = 1 }
    append(&exit.children, data_type { name = "parameters", length = 1 })
    append(&exit.children[0].children, data_type { name = "i64", length = 1 })
    ctx.identifier_data_types["exit"] = exit

    wait4 := data_type { name = "procedure", length = 1 }
    append(&wait4.children, data_type { name = "parameters", length = 1 })
    append(&wait4.children[0].children, data_type { name = "i64", length = 1 })
    ctx.identifier_data_types["wait4"] = wait4

    for node in nodes
    {
        if node.type == .PROCEDURE
        {
            ctx.identifier_data_types[node.children[0].value] = node.data_type
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
    name_node := node.children[0]

    procedure_ctx := copy_type_checking_context(ctx^)
    procedure_ctx.procedure_data_type = node.data_type

    params_data_type := node.data_type.children[0]
    for param_data_type in params_data_type.children
    {
        procedure_ctx.identifier_data_types[param_data_type.identifier] = param_data_type
    }

    if node.data_type.directive == "#extern" && len(node.children) == 2
    {
        fmt.println("Failed to type check procedure")
        fmt.printfln("#extern procedure '%s' cannot have a procedure body at line %i, column %i", name_node.value, node.line_number, node.column_number)
        ok = false
    }
    else if node.data_type.directive != "#extern" && len(node.children) == 1
    {
        fmt.println("Failed to type check procedure")
        fmt.printfln("Procedure '%s' must have a procedure body at line %i, column %i", name_node.value, node.line_number, node.column_number)
        ok = false
    }

    if len(node.children) == 2
    {
        statement_node := &node.children[1]
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

    expression_ok := type_check_expression(expression_node, ctx, { name = "bool", length = 1 })
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
        else_if_expression_ok := type_check_expression(&node.children[child_index], ctx, { name = "bool", length = 1 })
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

    expression_ok := type_check_expression(child_node, &for_ctx, { name = "bool", length = 1 })
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

    if lhs_node.value in ctx.identifier_data_types
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
            lhs_node.data_type = resolve_data_type(rhs_node.data_type)
        }
    }

    if lhs_node.data_type.name == ""
    {
        fmt.println("Failed to type check declaration")
        fmt.printfln("Could not determine type of '%s' at line %i, column %i", lhs_node.value, lhs_node.line_number, lhs_node.column_number)
        ok = false
    }

    ctx.identifier_data_types[lhs_node.value] = lhs_node.data_type

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

    if len(ctx.procedure_data_type.children) == 1
    {
        fmt.println("Failed to type check expression")
        fmt.printfln("Procedure has no return type at line %i, column %i", node.line_number, node.column_number)
        ok = false
    }

    expression_ok := type_check_expression(expression_node, ctx, ctx.procedure_data_type.children[1])
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

    node_resolved_data_type := resolve_data_type(node.data_type)
    expected_resolved_data_type := resolve_data_type(expected_data_type)
    data_type, coerce_ok := coerce_type(node_resolved_data_type, expected_resolved_data_type)
    if !coerce_ok
    {
        data_type_names: []string = { data_type_name(node_resolved_data_type), data_type_name(expected_resolved_data_type) }
        fmt.println("Failed to type check expression")
        fmt.printfln("Incompatible types %s at line %i, column %i", data_type_names, node.line_number, node.column_number)
        ok = false
    }

    propagate_data_type(node, data_type)

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

    lhs_resolved_data_type := resolve_data_type(lhs_node.data_type)
    rhs_resolved_data_type := resolve_data_type(rhs_node.data_type)
    data_type, coerce_ok := coerce_type(lhs_resolved_data_type, rhs_resolved_data_type)
    if !coerce_ok
    {
        data_type_names: []string = { data_type_name(lhs_resolved_data_type), data_type_name(rhs_resolved_data_type) }
        fmt.println("Failed to type check expression")
        fmt.printfln("Incompatible types %s at line %i, column %i", data_type_names, node.line_number, node.column_number)
        ok = false
    }

    _, comparison_operator := slice.linear_search(comparison_operators, node.type)
    if comparison_operator
    {
        node.data_type = { name = "bool", length = 1 }
        if data_type.name == "number"
        {
            propagate_data_type(lhs_node, { name = "f64", length = 1 })
            propagate_data_type(rhs_node, { name = "f64", length = 1 })
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
        propagate_data_type(lhs_node, data_type)
        propagate_data_type(rhs_node, data_type)
    }

    if data_type.length > 1 || data_type.is_reference
    {
        fmt.println("Failed to type check expression")
        fmt.printfln("Invalid type '%s' at line %i, column %i", data_type_name(node.data_type), node.line_number, node.column_number)
        return false
    }

    _, numerical_data_type := slice.linear_search(numerical_data_types, data_type.name)
    if data_type.name == "bool"
    {
        if node.type != .EQUAL && node.type != .NOT_EQUAL
        {
            fmt.println("Failed to type check expression")
            fmt.printfln("Invalid type '%s' at line %i, column %i", data_type_name(node.data_type), node.line_number, node.column_number)
            return false
        }
    }
    else if !numerical_data_type
    {
        fmt.println("Failed to type check expression")
        fmt.printfln("Invalid type '%s' at line %i, column %i", data_type_name(node.data_type), node.line_number, node.column_number)
        return false
    }

    return true
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
        node.data_type = ctx.identifier_data_types[node.value]

        if !(node.value in ctx.identifier_data_types)
        {
            fmt.println("Failed to type check primary")
            fmt.printfln("Undeclared identifier '%s' at line %i, column %i", node.value, node.line_number, node.column_number)
            ok = false
        }
    case .STRING:
        node.data_type = { name = "string", length = 1 }
    case .CSTRING:
        node.data_type = { name = "cstring", length = 1 }
    case .NUMBER:
        node.data_type = { name = "number", length = 1 }
    case .BOOLEAN:
        node.data_type = { name = "bool", length = 1 }
    case .NIL:
        node.data_type = { name = "nil", length = 1 }
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

    if !(name_node.value in ctx.identifier_data_types)
    {
        fmt.println("Failed to type check call")
        fmt.printfln("Undeclared identifier '%s' at line %i, column %i", name_node.value, name_node.line_number, name_node.column_number)
        ok = false
    }

    procedure_data_type := ctx.identifier_data_types[name_node.value]

    params_data_type := procedure_data_type.children[0]
    if len(params_data_type.children) != len(node.children) - 1
    {
        fmt.println("Failed to type check call")
        fmt.printfln("Wrong number of parameters at line %i, column %i", node.line_number, node.column_number)
        fmt.printfln("Expected: %i", len(params_data_type.children))
        fmt.printfln("Found: %i", len(node.children) - 1)
        ok = false
    }

    for child_index < len(node.children)
    {
        param_data_type := params_data_type.children[child_index - 1]

        param_node := &node.children[child_index]
        child_index += 1

        param_ok := type_check_expression(param_node, ctx, param_data_type)
        if !param_ok
        {
            ok = false
        }
    }

    node.data_type = procedure_data_type
    node.data_type.name = "call"

    return
}

type_check_variable :: proc(node: ^ast_node, ctx: ^type_checking_context) -> (ok: bool = true)
{
    identifier_node := node.type == .INDEX ? &node.children[0] : node

    if !(identifier_node.value in ctx.identifier_data_types)
    {
        fmt.println("Failed to type check variable")
        fmt.printfln("Undeclared identifier '%s' at line %i, column %i", identifier_node.value, node.line_number, node.column_number)
        ok = false
    }

    identifier_node.data_type = ctx.identifier_data_types[identifier_node.value]
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

    if ok && identifier_node.data_type.directive != "#boundless" && node.data_index >= identifier_node_copy.data_type.length
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
    for key in ctx.identifier_data_types
    {
        if inline || ctx.identifier_data_types[key].name == "procedure"
        {
            ctx_copy.identifier_data_types[key] = ctx.identifier_data_types[key]
        }
    }
    ctx_copy.procedure_data_type = ctx.procedure_data_type

    return ctx_copy
}

coerce_type :: proc(a: data_type, b: data_type) -> (data_type, bool)
{
    if a.name == "" || a.name == "nil"
    {
        return b, true
    }

    if b.name == "" || b.name == "nil"
    {
        return a, true
    }

    if a.directive != "#boundless" && b.directive != "#boundless" && a.length != b.length
    {
        return {}, false
    }

    if a.is_reference != b.is_reference
    {
        return {}, false
    }

    _, a_numerical_data_type := slice.linear_search(numerical_data_types, a.name)
    if b.name == "number" && !a_numerical_data_type
    {
        return {}, false
    }

    _, b_numerical_data_type := slice.linear_search(numerical_data_types, b.name)
    if a.name == "number" && !b_numerical_data_type
    {
        return {}, false
    }

    if a.name != "number" && b.name != "number" && a.name != b.name
    {
        return {}, false
    }

    if len(a.children) != len(b.children)
    {
        return {}, false
    }

    child_data_types: [dynamic]data_type
    for child_index := 0; child_index < len(a.children); child_index += 1
    {
        child_data_type, child_coerce_ok := coerce_type(a.children[child_index], b.children[child_index])
        if !child_coerce_ok
        {
            return {}, false
        }

        append(&child_data_types, child_data_type)
    }

    final_data_type := a.name == "number" ? b : a
    final_data_type.children = child_data_types
    return final_data_type, true
}

data_type_name :: proc(data_type: data_type) -> string
{
    name := data_type.name

    if data_type.is_reference
    {
        name = strings.concatenate({ "^", name })
    }

    if data_type.directive != ""
    {
        name = strings.concatenate({ data_type.directive, " ", name })
    }

    if data_type.length > 1
    {
        buf: [8]byte
        name = strings.concatenate({ name, "[", strconv.itoa(buf[:], data_type.length), "]" })
    }

    return name
}

resolve_data_type :: proc(the_data_type: data_type) -> data_type
{
    if the_data_type.name == "call" && len(the_data_type.children) == 2
    {
        return the_data_type.children[1]
    }

    return the_data_type
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
