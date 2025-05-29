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

type_check_program :: proc(nodes: [dynamic]ast_node) -> bool
{
    ctx: type_checking_context

    syscall := data_type { name = "procedure", directive = "#extern", length = 1 }
    append(&syscall.children, data_type { name = "parameters", length = 1 })
    append(&syscall.children[0].children, data_type { name = "i64", length = 1 })
    append(&syscall.children[0].children, data_type { name = "i64", length = 1 })
    append(&syscall.children[0].children, data_type { name = "i64", length = 1 })
    append(&syscall.children[0].children, data_type { name = "i64", length = 1 })
    append(&syscall.children[0].children, data_type { name = "i64", length = 1 })
    append(&syscall.children[0].children, data_type { name = "i64", length = 1 })
    append(&syscall.children[0].children, data_type { name = "i64", length = 1 })
    append(&syscall.children, data_type { name = "i64", length = 1 })
    ctx.identifier_data_types["syscall"] = syscall

    clone := data_type { name = "procedure", length = 1 }
    append(&clone.children, data_type { name = "parameters", length = 1 })
    append(&clone.children[0].children, data_type { name = "procedure", length = 1 })
    append(&clone.children[0].children[0].children, data_type { name = "parameters", length = 1 })
    append(&clone.children, data_type { name = "i64", length = 1 })
    ctx.identifier_data_types["clone"] = clone

    for node in nodes
    {
        if node.type == .ASSIGNMENT && node.children[0].data_type.name == "procedure"
        {
            ctx.identifier_data_types[node.children[0].value] = node.children[0].data_type
        }
    }

    for &node in nodes
    {
        type_check_statement(&node, &ctx) or_return
    }

    return true
}

type_check_statement :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    #partial switch node.type
    {
    case .IF:
        return type_check_if(node, ctx)
    case .FOR:
        return type_check_for(node, ctx)
    case .SCOPE:
        return type_check_scope(node, ctx)
    case .RETURN:
        return type_check_return(node, ctx)
    case .ASSIGNMENT:
        return type_check_assignment(node, ctx)
    case:
        return type_check_rhs_expression(node, ctx, {})
    }
}

type_check_if :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    child_index := 0
    expression_node := &node.children[child_index]
    child_index += 1

    type_check_rhs_expression(expression_node, ctx, { name = "bool", length = 1 }) or_return

    statement_node := &node.children[child_index]
    child_index += 1

    type_check_statement(statement_node, ctx) or_return

    for child_index + 1 < len(node.children)
    {
        type_check_rhs_expression(&node.children[child_index], ctx, { name = "bool", length = 1 }) or_return
        child_index += 1

        type_check_statement(&node.children[child_index], ctx) or_return
        child_index += 1
    }

    if child_index < len(node.children)
    {
        type_check_statement(&node.children[child_index], ctx) or_return
        child_index += 1
    }

    return true
}

type_check_for :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    for_ctx := copy_type_checking_context(ctx^, true)

    child_index := 0
    child_node := &node.children[child_index]
    child_index += 1

    if child_node.type == .ASSIGNMENT
    {
        type_check_assignment(child_node, &for_ctx) or_return

        child_node = &node.children[child_index]
        child_index += 1
    }

    type_check_rhs_expression(child_node, &for_ctx, { name = "bool", length = 1 }) or_return

    child_node = &node.children[child_index]
    child_index += 1

    if child_node.type == .ASSIGNMENT
    {
        type_check_assignment(child_node, &for_ctx) or_return

        child_node = &node.children[child_index]
        child_index += 1
    }

    type_check_statement(child_node, &for_ctx) or_return

    return true
}

type_check_scope :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    scope_ctx := copy_type_checking_context(ctx^, true)

    for &child_node in node.children
    {
        type_check_statement(&child_node, &scope_ctx) or_return
    }

    return true
}

type_check_return :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    expression_node := &node.children[0]

    if len(ctx.procedure_data_type.children) == 1
    {
        fmt.println("Failed to type check right-hand-side expression")
        file_error("Procedure has no return type in", node.file_info)
        return false
    }

    type_check_rhs_expression(expression_node, ctx, ctx.procedure_data_type.children[1]) or_return

    return true
}

type_check_assignment :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    lhs_node := &node.children[0]

    type_check_lhs_expression(lhs_node, ctx) or_return

    if len(node.children) == 2
    {
        rhs_node := &node.children[1]

        if lhs_node.data_type.name == "procedure"
        {
            if lhs_node.data_type.directive == "#extern"
            {
                fmt.println("Failed to type check assignment")
                file_error(fmt.aprintf("#extern procedure '%s' cannot have a procedure body in"), lhs_node.file_info)
                return false
            }

            procedure_ctx := copy_type_checking_context(ctx^)
            procedure_ctx.procedure_data_type = lhs_node.data_type

            params_data_type := lhs_node.data_type.children[0]
            for param_data_type in params_data_type.children
            {
                procedure_ctx.identifier_data_types[param_data_type.identifier] = param_data_type
            }

            if rhs_node.type != .IF && rhs_node.type != .FOR && rhs_node.type != .SCOPE && rhs_node.type != .RETURN && rhs_node.type != .ASSIGNMENT && rhs_node.type != .CALL
            {
                return_node := ast_node {
                    type = .RETURN,
                    file_info = rhs_node.file_info
                }
                append(&return_node.children, rhs_node^)
                rhs_node^ = return_node
            }

            type_check_statement(rhs_node, &procedure_ctx) or_return
        }
        else
        {
            if rhs_node.type == .IF || rhs_node.type == .FOR || rhs_node.type == .SCOPE || rhs_node.type == .RETURN || rhs_node.type == .ASSIGNMENT
            {
                fmt.println("Failed to type check assignment")
                file_error("Right-hand-side must be an expression in", lhs_node.file_info)
                return false
            }

            type_check_rhs_expression(rhs_node, ctx, lhs_node.data_type) or_return
        }

        if lhs_node.data_type.name == ""
        {
            lhs_node.data_type = resolve_data_type(rhs_node.data_type)
        }
    }

    if lhs_node.data_type.name == ""
    {
        fmt.println("Failed to type check assignment")
        fmt.printfln("Could not determine type of '%s' at line %i, column %i", lhs_node.value, lhs_node.file_info.line_number, lhs_node.file_info.column_number)
        return false
    }

    if !(lhs_node.value in ctx.identifier_data_types)
    {
        ctx.identifier_data_types[lhs_node.value] = lhs_node.data_type
    }

    return true
}

type_check_lhs_expression :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    type_check_primary(node, ctx) or_return

    if node.value in ctx.identifier_data_types
    {
        _, coerce_ok := coerce_type(node.data_type, ctx.identifier_data_types[node.value])
        if !coerce_ok
        {
            data_type_names: []string = { data_type_name(node.data_type), data_type_name(ctx.identifier_data_types[node.value]) }
            fmt.println("Failed to type check left-hand-side expression")
            file_error(fmt.aprintf("Incompatible types %s in", data_type_names), node.file_info)
            return false
        }
    }

    return true
}

type_check_rhs_expression :: proc(node: ^ast_node, ctx: ^type_checking_context, expected_data_type: data_type) -> bool
{
    type_check_rhs_expression_1(node, ctx) or_return

    node_resolved_data_type := resolve_data_type(node.data_type)
    expected_resolved_data_type := resolve_data_type(expected_data_type)
    data_type, coerce_ok := coerce_type(node_resolved_data_type, expected_resolved_data_type)
    if !coerce_ok
    {
        data_type_names: []string = { data_type_name(node_resolved_data_type), data_type_name(expected_resolved_data_type) }
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Incompatible types %s in", data_type_names), node.file_info)
        return false
    }

    upgrade_data_type(node, data_type)

    return true
}

type_check_rhs_expression_1 :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    _, binary_operator := slice.linear_search(binary_operators, node.type)
    if binary_operator
    {
        directive := node.data_type.directive
        type_check_primary(node, ctx) or_return

        if directive != ""
        {
            node.data_type.directive = directive
        }

        return true
    }

    lhs_node := &node.children[0]
    type_check_rhs_expression_1(lhs_node, ctx) or_return

    rhs_node := &node.children[1]
    type_check_rhs_expression_1(rhs_node, ctx) or_return

    lhs_resolved_data_type := resolve_data_type(lhs_node.data_type)
    rhs_resolved_data_type := resolve_data_type(rhs_node.data_type)
    data_type, coerce_ok := coerce_type(lhs_resolved_data_type, rhs_resolved_data_type)
    if !coerce_ok
    {
        data_type_names: []string = { data_type_name(lhs_resolved_data_type), data_type_name(rhs_resolved_data_type) }
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Incompatible types %s in", data_type_names), node.file_info)
        return false
    }

    _, comparison_operator := slice.linear_search(comparison_operators, node.type)
    if comparison_operator
    {
        node.data_type = { name = "bool", length = 1 }
        if data_type.name == "number"
        {
            upgrade_data_type(lhs_node, { name = "f64", length = 1 })
            upgrade_data_type(rhs_node, { name = "f64", length = 1 })
        }
        else
        {
            upgrade_data_type(lhs_node, data_type)
            upgrade_data_type(rhs_node, data_type)
        }
    }
    else
    {
        node.data_type = data_type
        upgrade_data_type(lhs_node, data_type)
        upgrade_data_type(rhs_node, data_type)
    }

    if data_type.length > 1 || data_type.is_reference
    {
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Invalid type %s in", data_type_name(node.data_type)), node.file_info)
        return false
    }

    _, numerical_data_type := slice.linear_search(numerical_data_types, data_type.name)
    if data_type.name == "bool"
    {
        if node.type != .EQUAL && node.type != .NOT_EQUAL
        {
            fmt.println("Failed to type check right-hand-side expression")
            file_error(fmt.aprintf("Invalid type %s in", data_type_name(node.data_type)), node.file_info)
            return false
        }
    }
    else if !numerical_data_type
    {
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Invalid type %s in", data_type_name(node.data_type)), node.file_info)
        return false
    }

    return true
}

type_check_primary :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    #partial switch node.type
    {
    case .REFERENCE:
        type_check_primary(&node.children[0], ctx) or_return

        node.data_type = node.children[0].data_type
        node.data_type.is_reference = true

        if node.children[0].data_type.is_reference
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Invalid type %s in", data_type_name(node.data_type)), node.file_info)
            return false
        }
    case .NEGATE:
        type_check_primary(&node.children[0], ctx) or_return

        node.data_type = node.children[0].data_type

        if node.data_type.is_reference && node.data_type.length > 1
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Invalid type %s in", data_type_name(node.data_type)), node.file_info)
            return false
        }
    case .DEREFERENCE:
        type_check_primary(&node.children[0], ctx) or_return

        node.data_type = node.children[0].data_type
        node.data_type.is_reference = false

        if !node.children[0].data_type.is_reference
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Invalid type %s in", data_type_name(node.data_type)), node.file_info)
            return false
        }
    case .INDEX:
        type_check_primary(&node.children[0], ctx) or_return

        identifier := node.children[0].value

        if node.children[0].data_type.is_reference
        {
            child_node := node.children[0]

            node.children[0] = {
                type = .DEREFERENCE,
                file_info = child_node.file_info
            }

            node.children[0].data_type = child_node.data_type
            node.children[0].data_type.is_reference = false

            append(&node.children[0].children, child_node)
        }

        node.data_type = node.children[0].data_type
        node.data_type.length = 1

        type_check_rhs_expression(&node.children[1], ctx, { name = "i64", length = 1 }) or_return

        if node.data_type.directive != "#boundless" && node.children[1].type == .NUMBER && strconv.atoi(node.children[1].value) >= node.children[0].data_type.length
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Index %i out of bounds of '%s' in", strconv.atoi(node.children[1].value), identifier), node.file_info)
            return false
        }
    case .CALL:
        type_check_call(node, ctx) or_return
    case .IDENTIFIER:
        if len(node.children) == 1
        {
            type_check_primary(&node.children[0], ctx)

            for member_data_type in node.children[0].data_type.children
            {
                if member_data_type.identifier == node.value
                {
                    node.data_type = member_data_type
                    break
                }
            }
        }
        else if node.value in ctx.identifier_data_types
        {
            node.data_type = ctx.identifier_data_types[node.value]
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
        type_check_rhs_expression_1(node, ctx) or_return
    }

    return true
}

type_check_call :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    if !(name_node.value in ctx.identifier_data_types)
    {
        fmt.println("Failed to type check call")
        file_error(fmt.aprintf("Undeclared identifier %s in", name_node.value), node.file_info)
        return false
    }

    procedure_data_type := ctx.identifier_data_types[name_node.value]

    params_data_type := procedure_data_type.children[0]
    if len(params_data_type.children) != len(node.children) - 1
    {
        fmt.println("Failed to type check call")
        file_error("Wrong number of parameters in", node.file_info)
        fmt.printfln("Expected: %i", len(params_data_type.children))
        fmt.printfln("Found: %i", len(node.children) - 1)
        return false
    }

    for child_index < len(node.children)
    {
        param_data_type := params_data_type.children[child_index - 1]

        param_node := &node.children[child_index]
        child_index += 1

        type_check_rhs_expression(param_node, ctx, param_data_type) or_return
    }

    node.data_type = procedure_data_type
    node.data_type.name = "call"

    return true
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
    if a.name == "" || a.name == "nil" || a.directive == "#untyped"
    {
        return b, true
    }

    if b.name == "" || b.name == "nil" || a.directive == "#untyped"
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

upgrade_data_type :: proc(node: ^ast_node, data_type: data_type)
{
    if node.data_type.name != "nil" && node.data_type.name != "number" && node.data_type.directive != "#untyped"
    {
        return
    }

    node.data_type = data_type
    for &child_node in node.children
    {
        upgrade_data_type(&child_node, data_type)
    }
}
