package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

gen_context :: struct
{
    data_sizes: map[string]int,

    in_proc: bool,

    stack_size: int,
    stack_variable_offsets: map[string]int,

    if_index: int,
    for_index: int
}

generate_program :: proc(file_name: string, nodes: [dynamic]ast_node)
{
    file, file_error := os.open(file_name, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o666)
    if file_error != nil
    {
        fmt.println("Failed to open asm file")
        os.exit(1)
    }
    defer os.close(file)

    fmt.fprintln(file, "global _start")
    fmt.fprintln(file, "_start:")

    ctx: gen_context

    ctx.data_sizes["i8"] = 1
    ctx.data_sizes["i16"] = 2
    ctx.data_sizes["i32"] = 4
    ctx.data_sizes["i64"] = 8

    for node in nodes
    {
        if node.type != .PROCEDURE
        {
            generate_statement(file, node, &ctx)
        }
    }

    fmt.fprintln(file, "  ; default exit")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, 0 ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")

    fmt.fprintln(file, "exit:")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, [rsp+8] ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    for node in nodes
    {
        if node.type == .PROCEDURE
        {
            generate_procedure(file, node, &ctx)
        }
    }
}

generate_procedure :: proc(file: os.Handle, node: ast_node, parent_ctx: ^gen_context)
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    scope_ctx := copy_gen_context(parent_ctx^)
    scope_ctx.in_proc = true
    for child_index + 1 < len(node.children)
    {
        param_node := node.children[child_index]
        child_index += 1

        scope_ctx.stack_size += scope_ctx.data_sizes[param_node.data_type.name]
        scope_ctx.stack_variable_offsets[param_node.value] = scope_ctx.stack_size
    }

    // Account for the instruction pointer pushed to the stack by 'call'
    scope_ctx.stack_size += 8

    fmt.fprintfln(file, "%s:", name_node.value)

    scope_node := node.children[child_index]
    child_index += 1

    generate_scope(file, scope_node, &scope_ctx, true)

    fmt.fprintln(file, "  ret ; return")
}

generate_statement :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    #partial switch node.type
    {
    case .IF:
        generate_if(file, node, ctx)
    case .FOR:
        generate_for(file, node, ctx)
    case .SCOPE:
        generate_scope(file, node, ctx)
    case .DECLARATION:
        generate_declaration(file, node, ctx)
    case .ASSIGNMENT:
        generate_assignment(file, node, ctx)
    case .RETURN:
        generate_return(file, node, ctx)
    case .CALL:
        fmt.fprintln(file, "  ; call")
        generate_call(file, node, ctx)
    case:
        fmt.println("Failed to generate statement")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }
}

generate_if :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    if_index := ctx.if_index
    ctx.if_index += 1

    fmt.fprintfln(file, "; if_%i", if_index)

    expression_node := node.children[0]
    scope_node := node.children[1]

    child_index := 2
    else_index := 0

    location := generate_expression(file, expression_node, ctx)
    fmt.fprintfln(file, "  test %s, %s ; test expression", location, location)
    fmt.fprintfln(file, "  jz .if_%i_%s ; skip main scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

    generate_scope(file, scope_node, ctx)

    for child_index + 1 < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        else_if_location := generate_expression(file, node.children[child_index], ctx)
        child_index += 1

        fmt.fprintfln(file, "  test %s, %s ; test expression", else_if_location, else_if_location)

        buf: [256]byte
        else_with_index := strings.concatenate({ "else_", strconv.itoa(buf[:], else_index) })
        fmt.fprintfln(file, "  jz .if_%i_%s ; skip else scope when false/zero", if_index, child_index + 1 < len(node.children) ? else_with_index : "end")

        generate_scope(file, node.children[child_index], ctx)
        child_index += 1
    }

    if child_index < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        generate_scope(file, node.children[child_index], ctx)
        child_index += 1
    }

    fmt.fprintfln(file, ".if_%i_end:", if_index)
}

generate_for :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    for_index := ctx.for_index
    ctx.for_index += 1

    if node.children[0].type == .DECLARATION
    {
        // TODO should be scoped to for loop
        declaration_node := node.children[0]
        generate_declaration(file, declaration_node, ctx)

        fmt.fprintfln(file, ".for_%i:", for_index)

        expression_node := node.children[1]
        location := generate_expression(file, expression_node, ctx)
        fmt.fprintfln(file, "  test %s, %s ; test expression", location, location)
        fmt.fprintfln(file, "  jz .for_%i_end ; skip for scope when false/zero", for_index)
    }
    else
    {
        fmt.fprintfln(file, ".for_%i:", for_index)

        expression_node := node.children[0]
        location := generate_expression(file, expression_node, ctx)
        fmt.fprintfln(file, "  test %s, %s ; test expression", location, location)
        fmt.fprintfln(file, "  jz .for_%i_end ; skip for scope when false/zero", for_index)
    }

    scope_node := node.children[len(node.children) - 1]
    generate_scope(file, scope_node, ctx)

    if node.children[0].type == .DECLARATION
    {
        assignment_node := node.children[2]
        generate_assignment(file, assignment_node, ctx)
    }

    fmt.fprintfln(file, "  jmp .for_%i ; back to top", for_index)

    fmt.fprintfln(file, ".for_%i_end:", for_index)
}

generate_scope :: proc(file: os.Handle, node: ast_node, parent_ctx: ^gen_context, include_end_label := false)
{
    fmt.fprintln(file, "; scope start")

    scope_ctx := copy_gen_context(parent_ctx^, true)

    for child_node in node.children
    {
        generate_statement(file, child_node, &scope_ctx)
    }

    parent_ctx.if_index = scope_ctx.if_index
    parent_ctx.for_index = scope_ctx.for_index

    if include_end_label
    {
        fmt.fprintln(file, ".end:")
    }

    scope_stack_size := scope_ctx.stack_size - parent_ctx.stack_size
    if scope_stack_size > 0
    {
        fmt.fprintln(file, "  ; close scope")
        fmt.fprintfln(file, "  add rsp, %i ; clear scope's stack", scope_stack_size)
    }

    fmt.fprintln(file, "; scope end")
}

generate_declaration :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; declare")

    lhs_node := node.children[0]

    data_size := ctx.data_sizes[lhs_node.data_type.name] * lhs_node.data_type.length
    fmt.fprintfln(file, "  sub rsp, %i ; allocate space in stack", data_size)
    ctx.stack_size += data_size
    ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size

    if len(node.children) > 1
    {
        rhs_node := node.children[1]

        location := generate_expression(file, rhs_node, ctx)

        fmt.fprintfln(file, "  mov [rsp], %s ; assign to top of stack", location)
    }
}

generate_assignment :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; assign")

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    offset := ctx.stack_size - ctx.stack_variable_offsets[lhs_node.value] + lhs_node.data_index * ctx.data_sizes[lhs_node.data_type.name]
    location := generate_expression(file, rhs_node, ctx)
    fmt.fprintfln(file, "  mov [rsp+%i], %s ; assign value", offset, location)
}

generate_return :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; return")

    expression_node := node.children[0]

    location := generate_expression(file, expression_node, ctx)

    if ctx.in_proc
    {
        fmt.fprintln(file, "  jmp .end ; skip to end")
    }
    else
    {
        data_size := ctx.data_sizes[expression_node.data_type.name]

        fmt.fprintfln(file, "  mov %s, 60 ; syscall: exit", register("ax", data_size))
        fmt.fprintfln(file, "  mov %s, %s ; arg0: exit_code", register("di", data_size), location)
        fmt.fprintln(file, "  syscall ; call kernel")
    }
}

generate_expression :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int = 8) -> string
{
    if node.type != .ADD && node.type != .SUBTRACT && node.type != .MULTIPLY && node.type != .DIVIDE
    {
        return generate_primary(file, node, ctx, register_num)
    }

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    lhs_register_num := register_num / 2 * 2 + 2
    rhs_register_num := lhs_register_num + 1

    lhs_location := generate_expression(file, lhs_node, ctx, lhs_register_num)
    rhs_location := generate_expression(file, rhs_node, ctx, rhs_register_num)

    data_size := ctx.data_sizes[node.data_type.name]
    location := register(register_num, data_size)

    #partial switch node.type
    {
    case .ADD:
        fmt.fprintfln(file, "  mov %s, %s ; add: assign lhs", location, lhs_location)
        fmt.fprintfln(file, "  add %s, %s ; add: do it!", location, rhs_location)
    case .SUBTRACT:
        fmt.fprintfln(file, "  mov %s, %s ; subtract: assign lhs", location, lhs_location)
        fmt.fprintfln(file, "  sub %s, %s ; subtract: do it!", location, rhs_location)
    case .MULTIPLY:
        fmt.fprintfln(file, "  mov %s, %s ; multiply: assign lhs", location, lhs_location)
        fmt.fprintfln(file, "  imul %s, %s ; multiply: do it!", location, rhs_location)
    case .DIVIDE:
        // dividend / divisor
        fmt.fprintfln(file, "  mov %s, 0 ; divide: assign zero to dividend high part", register("dx", data_size))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign lhs to dividend low part", register("ax", data_size), lhs_location)
        fmt.fprintfln(file, "  idiv %s ; divide: do it!", rhs_location)
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign result", register_num, register("ax", data_size))
    case:
        fmt.println("BUG: Failed to generate expression")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }

    return location
}

generate_primary :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int) -> string
{
    #partial switch node.type
    {
    case .CALL:
        return generate_call(file, node, ctx, register_num)
    case .IDENTIFIER:
        offset := ctx.stack_size - ctx.stack_variable_offsets[node.value] + node.data_index * ctx.data_sizes[node.data_type.name]
        location := register(register_num, ctx.data_sizes[node.data_type.name])
        fmt.fprintfln(file, "  mov %s, [rsp+%i] ; assign primary", location, offset)
        return location
    case .NUMBER:
        location := register(register_num, ctx.data_sizes[node.data_type.name])
        fmt.fprintfln(file, "  mov %s, %s ; assign primary", location, node.value)
        return location
    case .NEGATE:
        location := generate_primary(file, node.children[0], ctx, register_num)
        fmt.fprintfln(file, "  neg %s ; negate", location)
        return location
    case:
        return generate_expression(file, node, ctx, register_num)
    }
}

generate_call :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int = 8) -> string
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    params_stack_size := 0
    for child_index < len(node.children)
    {
        param_node := node.children[child_index]
        child_index += 1

        location := generate_expression(file, param_node, ctx)

        data_size := ctx.data_sizes[param_node.data_type.name]
        fmt.fprintfln(file, "  sub rsp, %i ; allocate space in stack", data_size)
        ctx.stack_size += data_size

        fmt.fprintfln(file, "  mov [rsp], %s ; assign to top of stack", location)

        params_stack_size += data_size
    }

    fmt.fprintfln(file, "  call %s ; call procedure", name_node.value)

    param_count := len(node.children) - 1
    fmt.fprintfln(file, "  add rsp, %i ; clear params from stack", params_stack_size)

    from_location := register(8, ctx.data_sizes[node.data_type.name])
    location := register(register_num, ctx.data_sizes[node.data_type.name])
    fmt.fprintfln(file, "  mov %s, %s ; assign return value", location, from_location)

    return location
}

copy_gen_context := proc(ctx: gen_context, inline := false) -> gen_context
{
    ctx_copy: gen_context
    ctx_copy.data_sizes = ctx.data_sizes
    ctx_copy.in_proc = ctx.in_proc
    ctx_copy.stack_size = ctx.stack_size

    if inline
    {
        for key in ctx.stack_variable_offsets
        {
            ctx_copy.stack_variable_offsets[key] = ctx.stack_variable_offsets[key]
        }

        ctx_copy.if_index = ctx.if_index
        ctx_copy.for_index = ctx.for_index
    }

    return ctx_copy
}

register :: proc
{
    register_named,
    register_numbered
}

register_named :: proc(name: string, size: int) -> string
{
    switch size
    {
    case 1:
        if strings.ends_with(name, "x")
        {
            first_char, _ := strings.substring(name, 0, 1)
            return strings.concatenate({ first_char, "l" })
        }
        else
        {
            return strings.concatenate({ name, "l" })
        }
    case 2:
        return name
    case 4:
        return strings.concatenate({ "e", name })
    case 8:
        return strings.concatenate({ "r", name })
    case:
        fmt.println("BUG: Unsupported register size")
        os.exit(1)
    }
}

register_numbered :: proc(number: int, size: int) -> string
{
    buf: [2]byte
    number_string := strconv.itoa(buf[:], number)

    switch size
    {
    case 1:
        return strings.concatenate({ "r", number_string, "b" })
    case 2:
        return strings.concatenate({ "r", number_string, "w" })
    case 4:
        return strings.concatenate({ "r", number_string, "d" })
    case 8:
        return strings.concatenate({ "r", number_string })
    case:
        fmt.println("BUG: Unsupported register size")
        os.exit(1)
    }
}
