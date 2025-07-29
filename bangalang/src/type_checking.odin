package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

type_checking_context :: struct
{
    references: map[string]string,
    identifiers: map[string]ast_node,
    procedure: ast_node
}

numerical_types: []string = { "[any_float]", "[any_int]", "[any_number]", "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64", "cint", "f32", "f64", "i8", "i16", "i32", "i64" }
float_types: []string = { "[any_float]", "f32", "f64" }
integer_types: []string = { "[any_int]", "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64", "cint", "i8", "i16", "i32", "i64" }
atomic_integer_types: []string = { "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64" }
signed_integer_types: []string = { "cint", "i8", "i16", "i32", "i64" }

type_check_module :: proc(module: ^module) -> bool
{
    module.ctx.identifiers["atomic_i8"] = { type = .type, value = "atomic_i8" }
    module.ctx.identifiers["atomic_i16"] = { type = .type, value = "atomic_i16" }
    module.ctx.identifiers["atomic_i32"] = { type = .type, value = "atomic_i32" }
    module.ctx.identifiers["atomic_i64"] = { type = .type, value = "atomic_i64" }
    module.ctx.identifiers["bool"] = { type = .type, value = "bool" }
    module.ctx.identifiers["cint"] = { type = .type, value = "cint" }
    module.ctx.identifiers["cstring"] = { type = .type, value = "cstring" }
    module.ctx.identifiers["f32"] = { type = .type, value = "f32" }
    module.ctx.identifiers["f64"] = { type = .type, value = "f64" }
    module.ctx.identifiers["i8"] = { type = .type, value = "i8" }
    module.ctx.identifiers["i16"] = { type = .type, value = "i16" }
    module.ctx.identifiers["i32"] = { type = .type, value = "i32" }
    module.ctx.identifiers["i64"] = { type = .type, value = "i64" }

    string_type_node := ast_node { type = .type, value = "[slice]" }
    append(&string_type_node.children, ast_node { type = .type, value = "i8" })
    module.ctx.identifiers["string"] = string_type_node

    syscall := ast_node { type = .identifier, value = "syscall" }
    append(&syscall.children, ast_node { type = .type, value = "[procedure]", allocator = "static", directive = "#extern" })
    append(&syscall.children[0].children, ast_node { type = .type, value = "[parameters]" })
    append(&syscall.children[0].children[0].children, ast_node { type = .identifier, value = "syscall_num" })
    append(&syscall.children[0].children[0].children[0].children, ast_node { type = .type, value = "i64" })
    append(&syscall.children[0].children[0].children, ast_node { type = .identifier, value = "arg0" })
    append(&syscall.children[0].children[0].children[1].children, ast_node { type = .type, value = "i64" })
    append(&syscall.children[0].children[0].children, ast_node { type = .identifier, value = "arg1" })
    append(&syscall.children[0].children[0].children[2].children, ast_node { type = .type, value = "i64" })
    append(&syscall.children[0].children[0].children, ast_node { type = .identifier, value = "arg2" })
    append(&syscall.children[0].children[0].children[3].children, ast_node { type = .type, value = "i64" })
    append(&syscall.children[0].children[0].children, ast_node { type = .identifier, value = "arg3" })
    append(&syscall.children[0].children[0].children[4].children, ast_node { type = .type, value = "i64" })
    append(&syscall.children[0].children[0].children, ast_node { type = .identifier, value = "arg4" })
    append(&syscall.children[0].children[0].children[5].children, ast_node { type = .type, value = "i64" })
    append(&syscall.children[0].children[0].children, ast_node { type = .identifier, value = "arg5" })
    append(&syscall.children[0].children[0].children[6].children, ast_node { type = .type, value = "i64" })
    append(&syscall.children[0].children, ast_node { type = .type, value = "i64" })
    module.ctx.identifiers["syscall"] = syscall

    import_proc := ast_node { type = .identifier, value = "import" }
    append(&import_proc.children, ast_node { type = .type, value = "[procedure]", allocator = "static" })
    append(&import_proc.children[0].children, ast_node { type = .type, value = "[parameters]" })
    append(&import_proc.children[0].children[0].children, ast_node { type = .identifier, value = "name" })
    append(&import_proc.children[0].children[0].children[0].children, module.ctx.identifiers["string"])
    append(&import_proc.children[0].children, ast_node { type = .type, value = "[module]" })
    module.ctx.identifiers["import"] = import_proc

    cmpxchg := ast_node { type = .identifier, value = "cmpxchg" }
    append(&cmpxchg.children, ast_node { type = .type, value = "[procedure]", allocator = "static" })
    append(&cmpxchg.children[0].children, ast_node { type = .type, value = "[parameters]" })
    append(&cmpxchg.children[0].children[0].children, ast_node { type = .identifier, value = "value" })
    append(&cmpxchg.children[0].children[0].children[0].children, ast_node { type = .reference })
    append(&cmpxchg.children[0].children[0].children[0].children[0].children, ast_node { type = .type, value = "i32" })
    append(&cmpxchg.children[0].children[0].children, ast_node { type = .identifier, value = "expected" })
    append(&cmpxchg.children[0].children[0].children[1].children, ast_node { type = .type, value = "i32" })
    append(&cmpxchg.children[0].children[0].children, ast_node { type = .identifier, value = "replacement" })
    append(&cmpxchg.children[0].children[0].children[2].children, ast_node { type = .type, value = "i32" })
    append(&cmpxchg.children[0].children, ast_node { type = .type, value = "bool" })
    module.ctx.identifiers["cmpxchg"] = cmpxchg

    for &node in module.nodes
    {
        if node.type == .assignment && len(node.children) > 1
        {
            rhs_node := &node.children[2]
            if rhs_node.type == .call && rhs_node.children[0].value == "import"
            {
                lhs_node := &node.children[0]
                reference := lhs_node.value
                name := strings.concatenate({ "stdlib/", reference, ".bang" })

                src_data, src_ok := os.read_entire_file(name)
                if !src_ok
                {
                    fmt.printfln("Failed to read module file %s", name)
                    return false
                }

                import_module(name, string(src_data)) or_return

                module.ctx.references[reference] = name
            }
        }
    }

    for &node in module.nodes
    {
        resolve_types(&node, &module.ctx)

        if node.type == .assignment && len(node.children) > 1 && is_type(&node.children[2])
        {
            lhs_node := &node.children[0]
            rhs_node := &node.children[2]

            name := lhs_node.value
            lhs_node^ = rhs_node^
            module.ctx.identifiers[name] = lhs_node^
        }
    }

    for &node in module.nodes
    {
        if node.type == .assignment
        {
            lhs_node := &node.children[0]
            lhs_type_node := get_type(lhs_node)
            if !is_member(lhs_node) && lhs_type_node != nil && lhs_type_node.value == "[procedure]"
            {
                lhs_type_node.allocator = "static"
                module.ctx.identifiers[lhs_node.value] = lhs_node^
            }
        }
    }

    for &node in module.nodes
    {
        if node.type == .assignment && len(node.children) > 1 && is_type(&node.children[2])
        {
            continue
        }

        type_check_statement(&node, &module.ctx) or_return
    }

    return true
}

type_check_statement :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    #partial switch node.type
    {
    case .if_:
        return type_check_if(node, ctx)
    case .for_:
        return type_check_for(node, ctx)
    case .return_:
        return type_check_return(node, ctx)
    case .scope:
        return type_check_scope(node, ctx)
    case .assignment:
        return type_check_assignment(node, ctx)
    case:
        return type_check_rhs_expression(node, ctx, nil)
    }
}

type_check_if :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    child_index := 0
    expression_node := &node.children[child_index]
    child_index += 1

    type_check_rhs_expression(expression_node, ctx, &ctx.identifiers["bool"]) or_return

    statement_node := &node.children[child_index]
    child_index += 1

    type_check_statement(statement_node, ctx) or_return

    for child_index + 1 < len(node.children)
    {
        type_check_rhs_expression(&node.children[child_index], ctx, &ctx.identifiers["bool"]) or_return
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

    _, statement := slice.linear_search(statement_node_types, child_node.type)
    if statement
    {
        type_check_statement(child_node, &for_ctx) or_return

        child_node = &node.children[child_index]
        child_index += 1
    }

    type_check_rhs_expression(child_node, &for_ctx, &for_ctx.identifiers["bool"]) or_return

    child_node = &node.children[child_index]
    child_index += 1

    if len(node.children) > child_index
    {
        type_check_statement(child_node, &for_ctx) or_return

        child_node = &node.children[child_index]
        child_index += 1
    }

    type_check_statement(child_node, &for_ctx) or_return

    return true
}

type_check_return :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    if len(node.children) > 0
    {
        procedure_node := &ctx.procedure
        procedure_type_node := get_type(procedure_node)

        expression_node := &node.children[0]
        type_check_rhs_expression(expression_node, ctx, &procedure_type_node.children[1]) or_return
    }

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

type_check_assignment :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    lhs_node := &node.children[0]

    type_check_lhs_expression(lhs_node, ctx) or_return

    if len(node.children) > 1
    {
        operator_node := &node.children[1]
        rhs_node := &node.children[2]

        lhs_type_node := get_type(lhs_node)
        if !is_member(lhs_node) && lhs_type_node != nil && lhs_type_node.value == "[procedure]"
        {
            if lhs_type_node.directive == "#extern"
            {
                fmt.println("Failed to type check assignment")
                file_error(fmt.aprintf("#extern procedure '%s' cannot have a procedure body in"), lhs_node.file_info)
                return false
            }

            procedure_ctx := copy_type_checking_context(ctx^)
            procedure_ctx.procedure = lhs_node^

            params_type_node := lhs_type_node.children[0]
            for param_node in params_type_node.children
            {
                procedure_ctx.identifiers[param_node.value] = param_node
            }

            return_type_node := len(lhs_type_node.children) == 2 ? &lhs_type_node.children[1] : nil
            if return_type_node != nil && rhs_node.type != .if_ && rhs_node.type != .for_ && rhs_node.type != .scope && rhs_node.type != .return_ && rhs_node.type != .assignment
            {
                return_node := ast_node {
                    type = .return_,
                    file_info = rhs_node.file_info
                }
                append(&return_node.children, rhs_node^)
                rhs_node^ = return_node
            }

            type_check_statement(rhs_node, &procedure_ctx) or_return
        }
        else
        {
            if rhs_node.type == .scope
            {
                rhs_node.type = .compound_literal
            }

            _, statement := slice.linear_search(statement_node_types, rhs_node.type)
            if statement
            {
                fmt.println("Failed to type check assignment")
                file_error("Right-hand-side must be an expression in", lhs_node.file_info)
                return false
            }

            type_check_rhs_expression(rhs_node, ctx, lhs_type_node) or_return
        }

        rhs_type_node := get_type(rhs_node)
        if lhs_type_node == nil
        {
            append(&lhs_node.children, rhs_type_node^)
        }

        if operator_node.type != .assign
        {
            _, numerical_type := slice.linear_search(numerical_types, rhs_type_node.value)
            if rhs_type_node.value == "[array]"
            {
                element_type_node := &rhs_type_node.children[0]
                _, float_type := slice.linear_search(float_types, element_type_node.value)
                if !float_type || operator_node.type == .modulo_assign
                {
                    fmt.println("Failed to type check assignment")
                    file_error(fmt.aprintf("Assignment operator %s is not valid for type '%s' in", operator_node.type, type_name(rhs_type_node)), operator_node.file_info)
                    return false
                }
            }
            else if !numerical_type
            {
                fmt.println("Failed to type check assignment")
                file_error(fmt.aprintf("Assignment operator %s is not valid for type '%s' in", operator_node.type, type_name(rhs_type_node)), operator_node.file_info)
                return false
            }

            _, float_type := slice.linear_search(float_types, rhs_type_node.value)
            if float_type && operator_node.type == .modulo_assign
            {
                fmt.println("Failed to type check assignment")
                file_error(fmt.aprintf("Assignment operator %s is not valid for type '%s' in", operator_node.type, type_name(rhs_type_node)), operator_node.file_info)
                return false
            }

            _, atomic_integer_type := slice.linear_search(atomic_integer_types, rhs_type_node.value)
            if atomic_integer_type && operator_node.type != .add_assign && operator_node.type != .subtract_assign
            {
                fmt.println("Failed to type check assignment")
                file_error(fmt.aprintf("Assignment operator %s is not valid for type '%s' in", operator_node.type, type_name(rhs_type_node)), operator_node.file_info)
                return false
            }
        }
    }

    lhs_type_node := get_type(lhs_node)
    if lhs_type_node == nil || lhs_type_node.value == "[any_float]" || lhs_type_node.value == "[any_int]" || lhs_type_node.value == "[any_number]" || lhs_type_node.value == "[any_string]"
    {
        fmt.println("Failed to type check assignment")
        fmt.printfln("Could not determine type of '%s' at line %i, column %i", lhs_node.value, lhs_node.file_info.line_number, lhs_node.file_info.column_number)
        return false
    }

    if !is_member(lhs_node) && !(lhs_node.value in ctx.identifiers)
    {
        ctx.identifiers[lhs_node.value] = lhs_node^
    }

    return true
}

type_check_lhs_expression :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    if is_member(node) || node.value in ctx.identifiers
    {
        type_node := get_type(node)

        if type_node != nil && (type_node.value != "[procedure]" || type_node.allocator != "static")
        {
            fmt.println("Failed to type check left-hand-side expression")
            file_error(fmt.aprintf("Cannot redefine type of '%s' in", node.value), node.file_info)
            return false
        }
    }

    type_check_primary(node, ctx, true) or_return

    return true
}

type_check_rhs_expression :: proc(node: ^ast_node, ctx: ^type_checking_context, expected_type_node: ^ast_node) -> bool
{
    if node.type == .compound_literal && expected_type_node != nil
    {
        append(&node.children, expected_type_node^)
    }

    type_check_rhs_expression_1(node, ctx) or_return

    type_node := get_type(node)
    coerced_type_node, coerce_ok := coerce_type(type_node, expected_type_node)
    if !coerce_ok
    {
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Types '%s' and '%s' are not compatible in", type_name(type_node), type_name(expected_type_node)), node.file_info)
        return false
    }

    if coerced_type_node != nil
    {
        upgrade_types(node, coerced_type_node, ctx)
    }

    return true
}

type_check_rhs_expression_1 :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    _, binary_operator := slice.linear_search(binary_operator_node_types, node.type)
    if !binary_operator
    {
        type_node := get_type(node)
        directive := node.directive != "" ? node.directive : (type_node != nil ? type_node.directive : "")
        type_check_primary(node, ctx, false) or_return

        if directive != ""
        {
            get_type(node).directive = directive
        }

        return true
    }

    lhs_node := &node.children[0]
    type_check_rhs_expression_1(lhs_node, ctx) or_return

    rhs_node := &node.children[1]
    type_check_rhs_expression_1(rhs_node, ctx) or_return

    lhs_type_node := get_type(lhs_node)
    rhs_type_node := get_type(rhs_node)
    coerced_type_node, coerce_ok := coerce_type(lhs_type_node, rhs_type_node)
    if !coerce_ok
    {
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Types '%s' and '%s' are not compatible in", type_name(lhs_type_node), type_name(rhs_type_node)), node.file_info)
        return false
    }

    _, comparison_operator := slice.linear_search(comparison_operator_node_types, node.type)
    if comparison_operator
    {
        append(&node.children, ctx.identifiers["bool"])
        if coerced_type_node.value == "[any_float]"
        {
            upgrade_types(lhs_node, &ctx.identifiers["f64"], ctx)
            upgrade_types(rhs_node, &ctx.identifiers["f64"], ctx)
        }
        else if coerced_type_node.value == "[any_number]"
        {
            upgrade_types(lhs_node, &ctx.identifiers["i64"], ctx)
            upgrade_types(rhs_node, &ctx.identifiers["i64"], ctx)
        }
        else
        {
            upgrade_types(lhs_node, coerced_type_node, ctx)
            upgrade_types(rhs_node, coerced_type_node, ctx)
        }
    }
    else
    {
        append(&node.children, coerced_type_node^)
        upgrade_types(lhs_node, coerced_type_node, ctx)
        upgrade_types(rhs_node, coerced_type_node, ctx)
    }

    _, numerical_type := slice.linear_search(numerical_types, coerced_type_node.value)
    if coerced_type_node.value == "bool"
    {
        if node.type != .equal && node.type != .not_equal && node.type != .and && node.type != .or
        {
            fmt.println("Failed to type check right-hand-side expression")
            file_error(fmt.aprintf("Binary operator %s is not valid for type '%s' in", node.type, type_name(get_type(node))), node.file_info)
            return false
        }
    }
    else if !numerical_type || node.type == .and || node.type == .or
    {
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Binary operator %s is not valid for type '%s' in", node.type, type_name(get_type(node))), node.file_info)
        return false
    }

    _, float_type := slice.linear_search(float_types, coerced_type_node.value)
    if float_type && node.type == .modulo
    {
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Binary operator %s is not valid for type '%s' in", node.type, type_name(get_type(node))), node.file_info)
        return false
    }

    _, atomic_integer_type := slice.linear_search(atomic_integer_types, coerced_type_node.value)
    if atomic_integer_type && !comparison_operator
    {
        fmt.println("Failed to type check right-hand-side expression")
        file_error(fmt.aprintf("Binary operator %s is not valid for type '%s' in", node.type, type_name(get_type(node))), node.file_info)
        return false
    }

    return true
}

type_check_primary :: proc(node: ^ast_node, ctx: ^type_checking_context, allow_undefined: bool) -> bool
{
    if node.type != .compound_literal && len(node.children) > 0 && !is_type(&node.children[0])
    {
        type_check_primary(&node.children[0], ctx, allow_undefined) or_return
    }

    #partial switch node.type
    {
    case .reference:
        _, literal := slice.linear_search(literal_node_types, node.children[0].type)
        if literal
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Cannot reference '%s' literal in", node.children[0].type), node.file_info)
            return false
        }

        type_node := ast_node { type = .reference }
        append(&type_node.children, get_type(&node.children[0])^)
        append(&node.children, type_node)
    case .negate:
        child_type_node := get_type(&node.children[0])
        _, numerical_type := slice.linear_search(numerical_types, child_type_node.value)
        if !numerical_type
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Cannot negate type '%s' in", type_name(child_type_node)), node.file_info)
            return false
        }

        append(&node.children, child_type_node^)
    case .not:
        child_type_node := get_type(&node.children[0])
        if child_type_node.value != "bool"
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Cannot invert type '%s' in", type_name(child_type_node)), node.file_info)
            return false
        }

        append(&node.children, child_type_node^)
    case .dereference:
        child_type_node := get_type(&node.children[0])
        if child_type_node.type != .reference
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Cannot dereference type '%s' in", type_name(child_type_node)), node.file_info)
            return false
        }

        append(&node.children, child_type_node.children[0])
    case .index:
        identifier := node.children[0].value // TODO *eyebrow raise*

        auto_dereference(&node.children[0])

        child_type_node := get_type(&node.children[0])
        if child_type_node.value != "[array]" && child_type_node.value != "[slice]"
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("Cannot index type '%s' in", type_name(child_type_node)), node.file_info)
            return false
        }

        append(&node.children, child_type_node.children[0])

        any_int_type_node := ast_node { type = .type, value = "[any_int]" }

        type_check_rhs_expression(&node.children[1], ctx, &any_int_type_node) or_return
        upgrade_types(&node.children[1], &ctx.identifiers["i64"], ctx)

        if len(node.children) == 4
        {
            type_check_rhs_expression(&node.children[2], ctx, &any_int_type_node) or_return
            upgrade_types(&node.children[2], &ctx.identifiers["i64"], ctx)

            type_node := ast_node { type = .type, value = "[slice]" }
            append(&type_node.children, get_type(node)^)
            get_type(node)^ = type_node
        }

        if child_type_node.value == "[array]"
        {
            length := strconv.atoi(child_type_node.children[1].value)

            if child_type_node.directive != "#boundless" && node.children[1].type == .number && strconv.atoi(node.children[1].value) >= length
            {
                fmt.println("Failed to type check primary")
                file_error(fmt.aprintf("Index %i out of bounds of '%s' in", strconv.atoi(node.children[1].value), identifier), node.file_info)
                return false
            }
        }
    case .call:
        type_check_call(node, ctx) or_return
    case .identifier:
        if is_member(node)
        {
            child_node := &node.children[0]
            auto_dereference(child_node)

            child_type_node := get_type(child_node)
            switch child_type_node.value
            {
            case "[array]", "[slice]":
                if node.value == "raw"
                {
                    raw_type_node := ast_node { type = .reference }
                    append(&raw_type_node.children, child_type_node.children[0])
                    append(&node.children, raw_type_node)
                }
                else if node.value == "length"
                {
                    append(&node.children, ctx.identifiers["i64"])
                }
            case "[module]":
                if !(child_node.value in ctx.references)
                {
                    fmt.println("Failed to type check primary")
                    file_error(fmt.aprintf("Module '%s' has not been imported in", child_node.value), node.file_info)
                    return false
                }

                module := &imported_modules[ctx.references[child_node.value]]
                if !(node.value in module.ctx.identifiers)
                {
                    fmt.println("Failed to type check primary")
                    file_error(fmt.aprintf("'%s' is not a member in", node.value), node.file_info)
                    return false
                }

                append(&node.children, get_type(&module.ctx.identifiers[node.value])^)
            case "[struct]":
                found_member := false
                for &member_node in child_type_node.children
                {
                    if member_node.value == node.value
                    {
                        append(&node.children, get_type(&member_node)^)
                        found_member = true
                        break
                    }
                }

                if !found_member
                {
                    fmt.println("Failed to type check primary")
                    file_error(fmt.aprintf("'%s' is not a member in", node.value), node.file_info)
                    return false
                }
            case:
                fmt.println("Failed to type check primary")
                file_error(fmt.aprintf("'%s' is not a member in", node.value), node.file_info)
                return false
            }
        }
        else if node.value in ctx.identifiers
        {
            append(&node.children, get_type(&ctx.identifiers[node.value])^)
        }
        else if node.value in ctx.references
        {
            append(&node.children, ast_node {  type = .type, value = "[module]"})
        }
        else if !allow_undefined
        {
            fmt.println("Failed to type check primary")
            file_error(fmt.aprintf("'%s' is not defined in", node.value), node.file_info)
            return false
        }
    case .string_:
        append(&node.children, ast_node { type = .type, value = "[any_string]" })
    case .number:
        type := strings.contains(node.value, ".") ? "[any_float]" : "[any_number]"
        append(&node.children, ast_node { type = .type, value = type })
    case .boolean:
        append(&node.children, ctx.identifiers["bool"])
    case .compound_literal:
        type_node := get_type(node)

        for child_node in node.children[:len(node.children) - 1]
        {
            if child_node.type != .assignment
            {
                fmt.println("Failed to type check primary")
                file_error("Compound literal can only contain assignments in", node.file_info)
                return false
            }

            child_lhs_node := &child_node.children[0]
            if child_lhs_node.type != .identifier || len(child_lhs_node.children) > 0
            {
                fmt.println("Failed to type check primary")
                file_error("Compound literal can only contain assignments to members in", node.file_info)
                return false
            }

            found_member := false
            if type_node.value == "[struct]"
            {
                for &member_node in type_node.children
                {
                    if member_node.value == child_lhs_node.value
                    {
                        append(&child_lhs_node.children, get_type(&member_node)^)
                        found_member = true
                        break
                    }
                }
            }
            else if type_node.value == "[slice]"
            {
                switch child_lhs_node.value
                {
                case "raw":
                    raw_type_node := ast_node { type = .reference }
                    append(&raw_type_node.children, type_node.children[0])
                    append(&child_lhs_node.children, raw_type_node)
                    found_member = true
                case "length":
                    append(&child_lhs_node.children, ctx.identifiers["i64"])
                    found_member = true
                }
            }
            else
            {
                fmt.println("Failed to type check primary")
                file_error(fmt.aprintf("Cannot use compound literal with type '%s' in", type_node.value), node.file_info)
                return false
            }

            if !found_member
            {
                fmt.println("Failed to type check primary")
                file_error(fmt.aprintf("'%s' is not a member in", child_lhs_node.value), node.file_info)
                return false
            }

            if len(child_node.children) == 1
            {
                fmt.println("Failed to type check primary")
                file_error("Compound literal can only contain assignments with right-hand-side expressions in", node.file_info)
                return false
            }

            child_rhs_node := &child_node.children[2]
            type_check_rhs_expression(child_rhs_node, ctx, get_type(child_lhs_node)) or_return
        }
    case .nil_:
        append(&node.children, ast_node { type = .type, value = "nil" })
    case .type:
        assert(false, "Failed to type check primary")
    case:
        type_check_rhs_expression_1(node, ctx) or_return
    }

    return true
}

type_check_call :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    child_index := 0
    procedure_node := &node.children[child_index]
    child_index += 1

    if is_type(procedure_node)
    {
        if 1 != len(node.children) - 1
        {
            fmt.println("Failed to type check call")
            file_error("Wrong number of parameters in", node.file_info)
            fmt.printfln("Expected: %i", 1)
            fmt.printfln("Found: %i", len(node.children) - 1)
            return false
        }

        param_node := &node.children[child_index]
        child_index += 1

        type_check_rhs_expression(param_node, ctx, nil) or_return

        param_type_node := get_type(param_node)
        _, param_numerical_type := slice.linear_search(numerical_types, param_type_node.value)
        _, return_numerical_type := slice.linear_search(numerical_types, procedure_node.value)
        if !param_numerical_type && !return_numerical_type
        {
            fmt.println("Failed to type check call")
            file_error(fmt.aprintf("Type '%s' cannot be converted to type '%s' in", param_type_node.value, procedure_node.value), node.file_info)
            return false
        }

        append(&node.children, procedure_node^)

        type_node := ast_node { type = .type, value = "[procedure]" }
        append(&type_node.children, ast_node { type = .type, value = "[parameters]" })
        append(&type_node.children[0].children, ast_node { type = .identifier, value = "value" })
        append(&type_node.children[0].children[0].children, param_type_node^)
        append(&type_node.children, procedure_node^)
        append(&procedure_node.children, type_node)

        return true
    }

    procedure_type_node := get_type(procedure_node)
    if procedure_type_node.value != "[procedure]"
    {
        fmt.println("Failed to type check call")
        file_error(fmt.aprintf("'%s' does not refer to a procedure in", procedure_node.value), node.file_info)
        return false
    }

    params_type_node := procedure_type_node.children[0]
    if len(params_type_node.children) != len(node.children) - 1
    {
        fmt.println("Failed to type check call")
        file_error("Wrong number of parameters in", node.file_info)
        fmt.printfln("Expected: %i", len(params_type_node.children))
        fmt.printfln("Found: %i", len(node.children) - 1)
        return false
    }

    for child_index < len(node.children)
    {
        param_node_from_type := &params_type_node.children[child_index - 1]

        param_node := &node.children[child_index]
        child_index += 1

        type_check_rhs_expression(param_node, ctx, get_type(param_node_from_type)) or_return
    }

    if len(procedure_type_node.children) == 2
    {
        return_type_node := &procedure_type_node.children[1]
        append(&node.children, return_type_node^)
    }

    return true
}

copy_type_checking_context := proc(ctx: type_checking_context, inline := false) -> type_checking_context
{
    ctx_copy: type_checking_context
    for key in ctx.references
    {
        ctx_copy.references[key] = ctx.references[key]
    }

    for key in ctx.identifiers
    {
        identifier_node := &ctx.identifiers[key]
        if inline || is_type(identifier_node) || get_type(identifier_node).value == "[procedure]"
        {
            ctx_copy.identifiers[key] = ctx.identifiers[key]
        }
    }

    if inline
    {
        ctx_copy.procedure = ctx.procedure
    }

    return ctx_copy
}

coerce_type :: proc(a: ^ast_node, b: ^ast_node) -> (^ast_node, bool)
{
    if a == nil || a.value == "nil" || a.directive == "#untyped"
    {
        return b, true
    }

    if b == nil || b.value == "nil" || b.directive == "#untyped"
    {
        return a, true
    }

    if a.type != b.type
    {
        return nil, false
    }

    compatible_value_types := false

    if a.value != b.value
    {
        if a.type == .type
        {
            _, a_numerical_type := slice.linear_search(numerical_types, a.value)
            if b.value == "[any_number]" && !a_numerical_type
            {
                return nil, false
            }

            _, b_numerical_type := slice.linear_search(numerical_types, b.value)
            if a.value == "[any_number]" && !b_numerical_type
            {
                return nil, false
            }

            if a.value != "[any_number]" && b.value != "[any_number]"
            {
                _, a_float_type := slice.linear_search(float_types, a.value)
                if b.value == "[any_float]" && !a_float_type
                {
                    return nil, false
                }

                _, b_float_type := slice.linear_search(float_types, b.value)
                if a.value == "[any_float]" && !b_float_type
                {
                    return nil, false
                }

                _, a_integer_type := slice.linear_search(integer_types, a.value)
                if b.value == "[any_int]" && !a_integer_type
                {
                    return nil, false
                }

                _, b_integer_type := slice.linear_search(integer_types, b.value)
                if a.value == "[any_int]" && !b_integer_type
                {
                    return nil, false
                }
            }

            a_string := a.value == "[slice]" && a.children[0].value == "i8"
            a_cstring := a.value == "cstring"
            if b.value == "[any_string]" && !a_string && !a_cstring
            {
                return nil, false
            }

            b_string := b.value == "[slice]" && b.children[0].value == "i8"
            b_cstring := b.value == "cstring"
            if a.value == "[any_string]" && !b_string && !b_cstring
            {
                return nil, false
            }

            if a.value != "[any_number]" && b.value != "[any_number]" &&
               a.value != "[any_float]" && b.value != "[any_float]" &&
               a.value != "[any_int]" && b.value != "[any_int]" &&
               a.value != "[any_string]" && b.value != "[any_string]"
            {
                return nil, false
            }

            compatible_value_types = true
        }
        else
        {
            return nil, false
        }
    }

    if !compatible_value_types
    {
        if len(a.children) != len(b.children)
        {
            return nil, false
        }

        for child_index := 0; child_index < len(a.children); child_index += 1
        {
            _, child_coerce_ok := coerce_type(&a.children[child_index], &b.children[child_index])
            if !child_coerce_ok
            {
                return nil, false
            }
        }
    }

    if a.value == "[any_number]"
    {
        return b, true
    }
    else if b.value == "[any_number]"
    {
        return a, true
    }

    return a.value == "[any_float]" || a.value == "[any_int]" || a.value == "[any_string]" ? b : a, true
}

type_name :: proc(type_node: ^ast_node) -> string
{
    assert(type_node.type == .reference || type_node.type == .type, "Invalid type")

    prefix := type_node.directive != "" ? strings.concatenate({ type_node.directive, " " }) : ""

    if type_node.type == .reference
    {
        return strings.concatenate({ prefix, "^", type_name(&type_node.children[0]) })
    }

    switch type_node.value
    {
    case "[any_float]":
        return strings.concatenate({ prefix, "<any float>" })
    case "[any_int]":
        return strings.concatenate({ prefix, "<any int>" })
    case "[any_number]":
        return strings.concatenate({ prefix, "<any number>" })
    case "[any_string]":
        return strings.concatenate({ prefix, "<any string>" })
    case "[array]":
        return strings.concatenate({ prefix, type_name(&type_node.children[0]), "[", type_node.children[1].value, "]" })
    case "[procedure]":
        param_type_names: [dynamic]string
        params_type_node := type_node.children[0]
        for &param_node in params_type_node.children
        {
            append(&param_type_names, strings.concatenate({ param_node.value, ": ", type_name(get_type(&param_node)) }))
        }

        return_type_name: string
        if len(type_node.children) == 2
        {
            return_type_node := &type_node.children[1]
            return_type_name = strings.concatenate({ " -> ", type_name(return_type_node) })
        }

        return strings.concatenate({ prefix, "proc(", strings.join(param_type_names[:], ", "), ")", return_type_name })
    case "[slice]":
        return strings.concatenate({ prefix, type_name(&type_node.children[0]), "[]" })
    case "[struct]":
        member_type_names: [dynamic]string
        for &member_node in type_node.children
        {
            append(&member_type_names, strings.concatenate({ member_node.value, ": ", type_name(get_type(&member_node)) }))
        }

        return strings.concatenate({ prefix, "struct { ", strings.join(member_type_names[:], ", "), " }" })
    }

    return strings.concatenate({ prefix, type_node.value })
}

is_type :: proc(type_node: ^ast_node) -> bool
{
    if type_node.type == .type
    {
        return true
    }

    if type_node.type == .reference
    {
        return is_type(&type_node.children[0])
    }

    return false
}

get_type :: proc(node: ^ast_node) -> ^ast_node
{
    child_count := len(node.children)
    if child_count == 0
    {
        return nil
    }

    if is_type(&node.children[child_count - 1])
    {
        return &node.children[child_count - 1]
    }

    return nil
}

get_type_value :: proc(type_node: ^ast_node) -> string
{
    assert(type_node.type == .reference || type_node.type == .type, "Invalid type")

    if len(type_node.children) > 0 && type_node.value == ""
    {
        return get_type_value(&type_node.children[0])
    }

    return type_node.value
}

upgrade_types :: proc(node: ^ast_node, new_type_node: ^ast_node, ctx: ^type_checking_context)
{
    if node.type == .type
    {
        if new_type_node.value == "[any_string]" && node.value == "[any_string]"
        {
            node^ = ctx.identifiers["string"]
        }
        else if node.value == "nil" || node.value == "[any_float]" || node.value == "[any_int]" || node.value == "[any_number]" || node.value == "[any_string]" || node.directive == "#untyped"
        {
            node^ = new_type_node^
        }
    }

    for &child_node in node.children
    {
        upgrade_types(&child_node, new_type_node, ctx)
    }
}

resolve_types :: proc(node: ^ast_node, ctx: ^type_checking_context) -> bool
{
    if node.type == .identifier || node.type == .type
    {
        if len(node.children) > 0 && (node.children[0].type == .identifier || node.children[0].type == .type)
        {
            child_node := &node.children[0]
            if child_node.value in ctx.references
            {
                module := &imported_modules[ctx.references[child_node.value]]
                if node.value in module.ctx.identifiers
                {
                    identifier_node := &module.ctx.identifiers[node.value]
                    if is_type(identifier_node)
                    {
                        node^ = identifier_node^
                        return true
                    }
                }
            }
        }
        else if node.value in ctx.identifiers
        {
            identifier_node := &ctx.identifiers[node.value]
            if is_type(identifier_node)
            {
                node^ = identifier_node^
                return true
            }
        }
    }

    if node.type == .type && node.value[0] != '['
    {
        fmt.println("Failed to resolve type")
        file_error(fmt.aprintf("Type '%s' was not found in", node.value), node.file_info)
        return false
    }

    for &child_node in node.children
    {
        if resolve_types(&child_node, ctx)
        {
            if node.type == .index
            {
                node.type = .type
                node.value = len(node.children) == 1 ? "[slice]" : "[array]"
            }
        }
    }

    return false
}

is_member :: proc(node: ^ast_node) -> bool
{
    if node.type != .identifier || len(node.children) == 0
    {
        return false
    }

    final_node := node
    for final_node.children[0].type == .dereference || final_node.children[0].type == .reference
    {
        final_node = &final_node.children[0]
    }

    return final_node.children[0].type == .identifier
}

auto_dereference :: proc(node: ^ast_node)
{
    type_node := get_type(node)^
    if type_node.type != .reference
    {
        return
    }

    child_node := node^

    node^ = {
        type = .dereference,
        file_info = child_node.file_info
    }

    append(&node.children, child_node)
    append(&node.children, type_node.children[0])

    // TODO not sure if this best, propagates #boundless
    get_type(node).directive = type_node.directive
}
