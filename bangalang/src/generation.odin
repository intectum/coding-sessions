package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

memory_type :: enum
{
    IMMEDIATE,
    POINTER,
    REGISTER
}

memory :: struct
{
    type: memory_type,
    value: string,
    offset: int
}

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
    location = move_to_register(file, location, 8, ctx.data_sizes[expression_node.data_type.name])
    fmt.fprintfln(file, "  test %s, %s ; test expression", operand(location), operand(location))
    fmt.fprintfln(file, "  jz .if_%i_%s ; skip main scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

    generate_scope(file, scope_node, ctx)

    for child_index + 1 < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        else_if_location := generate_expression(file, node.children[child_index], ctx)
        else_if_location = move_to_register(file, else_if_location, 8, ctx.data_sizes[node.children[child_index].data_type.name])
        child_index += 1

        fmt.fprintfln(file, "  test %s, %s ; test expression", operand(else_if_location), operand(else_if_location))

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
        location = move_to_register(file, location, 8, ctx.data_sizes[expression_node.data_type.name])
        fmt.fprintfln(file, "  test %s, %s ; test expression", operand(location), operand(location))
        fmt.fprintfln(file, "  jz .for_%i_end ; skip for scope when false/zero", for_index)
    }
    else
    {
        fmt.fprintfln(file, ".for_%i:", for_index)

        expression_node := node.children[0]
        location := generate_expression(file, expression_node, ctx)
        location = move_to_register(file, location, 8, ctx.data_sizes[expression_node.data_type.name])
        fmt.fprintfln(file, "  test %s, %s ; test expression", operand(location), operand(location))
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
        copy(file, location, { .POINTER, "rsp", 0 }, data_size)
    }
}

generate_assignment :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; assign")

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    variable_position := ctx.stack_size - ctx.stack_variable_offsets[lhs_node.value]
    offset := variable_position + lhs_node.data_index * ctx.data_sizes[lhs_node.data_type.name]
    location := generate_expression(file, rhs_node, ctx)
    copy(file, location, { .POINTER, "rsp", offset }, ctx.data_sizes[lhs_node.data_type.name])
}

generate_return :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; return")

    expression_node := node.children[0]

    location := generate_expression(file, expression_node, ctx)

    data_size := ctx.data_sizes[expression_node.data_type.name]

    if ctx.in_proc
    {
        move_to_register(file, location, 8, data_size)
        fmt.fprintln(file, "  jmp .end ; skip to end")
    }
    else
    {
        fmt.fprintfln(file, "  mov %s, 60 ; syscall: exit", operand(register("ax", data_size)))
        fmt.fprintfln(file, "  mov %s, %s ; arg0: exit_code", operand(register("di", data_size)), operand(location))
        fmt.fprintln(file, "  syscall ; call kernel")
    }
}

generate_expression :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int = 8) -> memory
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
    result_location := register(register_num, data_size)

    lhs_operand := operand(lhs_location)
    rhs_operand := operand(rhs_location)
    result_operand := operand(result_location)

    #partial switch node.type
    {
    case .ADD:
        result_location = move_to_register(file, lhs_location, register_num, data_size)
        fmt.fprintfln(file, "  add %s, %s ; add", operand(result_location), rhs_operand)
    case .SUBTRACT:
        result_location = move_to_register(file, lhs_location, register_num, data_size)
        fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(result_location), rhs_operand)
    case .MULTIPLY:
        result_location = move_to_register(file, lhs_location, register_num, data_size)
        fmt.fprintfln(file, "  imul %s, %s ; multiply", operand(result_location), rhs_operand)
    case .DIVIDE:
        // dividend / divisor
        fmt.fprintfln(file, "  mov %s, 0 ; divide: assign zero to dividend high part", operand(register("dx", data_size)))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign lhs to dividend low part", operand(register("ax", data_size)), lhs_operand)
        fmt.fprintfln(file, "  idiv %s ; divide: do it!", rhs_operand)
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign result", result_operand, operand(register("ax", data_size)))
    case:
        fmt.println("BUG: Failed to generate expression")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }

    return result_location
}

generate_primary :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int) -> memory
{
    #partial switch node.type
    {
    case .CALL:
        return generate_call(file, node, ctx, register_num)
    case .IDENTIFIER:
        variable_position := ctx.stack_size - ctx.stack_variable_offsets[node.value]
        offset := variable_position + node.data_index * ctx.data_sizes[node.data_type.name]
        return { .POINTER, "rsp", offset }
    case .NUMBER:
        return { .IMMEDIATE, node.value, 0 }
    case .NEGATE:
        location := generate_primary(file, node.children[0], ctx, register_num)
        location = move_to_register(file, location, register_num, ctx.data_sizes[node.data_type.name])
        fmt.fprintfln(file, "  neg %s ; negate", operand(location))
        return location
    case:
        return generate_expression(file, node, ctx, register_num)
    }
}

generate_call :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int = 8) -> memory
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    params_stack_size := 0
    for child_index < len(node.children)
    {
        param_node := node.children[child_index]
        child_index += 1

        data_size := ctx.data_sizes[param_node.data_type.name]

        fmt.fprintfln(file, "  sub rsp, %i ; allocate space in stack", data_size)
        ctx.stack_size += data_size

        location := generate_expression(file, param_node, ctx)
        copy(file, location, { .POINTER, "rsp", 0 }, data_size)

        params_stack_size += data_size
    }

    fmt.fprintfln(file, "  call %s ; call procedure", name_node.value)

    param_count := len(node.children) - 1
    fmt.fprintfln(file, "  add rsp, %i ; clear params from stack", params_stack_size)
    ctx.stack_size -= params_stack_size

    data_size := ctx.data_sizes[node.data_type.name]
    location := register(register_num, data_size)
    if register_num != 8
    {
        from_location := register(8, data_size)
        copy(file, from_location, location, data_size)
    }

    return location
}

move_to_register :: proc(file: os.Handle, location: memory, number: int, size: int) -> memory
{
    if location.type == .REGISTER
    {
        return location
    }

    register_location := register(number, size)
    copy(file, location, register_location, size)
    return register_location
}

copy :: proc(file: os.Handle, src: memory, dest: memory, size: int)
{
    if dest.type == .IMMEDIATE
    {
        fmt.println("BUG: Cannot move to immediate")
        os.exit(1)
    }

    if src.type == .REGISTER || dest.type == .REGISTER
    {
        fmt.fprintfln(file, "  mov %s, %s ; copy", operand(dest), operand(src))
    }
    else if src.type == .IMMEDIATE
    {
        fmt.fprintfln(file, "  mov %s %s, %s ; copy", operation_size(size), operand(dest), operand(src))
    }
    else
    {
        fmt.fprintfln(file, "  lea rsi, %s ; copy: src", operand(src));
        fmt.fprintfln(file, "  lea rdi, %s ; copy: dest", operand(dest));
        fmt.fprintfln(file, "  mov rcx, %i ; copy: count", size);
        fmt.fprintln(file, "  rep movsb ; copy: do it!");
    }
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

register_named :: proc(name: string, size: int) -> memory
{
    switch size
    {
    case 1:
        if strings.ends_with(name, "x")
        {
            first_char, _ := strings.substring(name, 0, 1)
            return { .REGISTER, strings.concatenate({ first_char, "l" }), 0 }
        }
        else
        {
            return { .REGISTER, strings.concatenate({ name, "l" }), 0 }
        }
    case 2:
        return { .REGISTER, name, 0 }
    case 4:
        return { .REGISTER, strings.concatenate({ "e", name }), 0 }
    case 8:
        return { .REGISTER, strings.concatenate({ "r", name }), 0 }
    case:
        fmt.println("BUG: Unsupported register size")
        os.exit(1)
    }
}

register_numbered :: proc(number: int, size: int) -> memory
{
    buf: [2]byte
    number_string := strconv.itoa(buf[:], number)

    switch size
    {
    case 1:
        return { .REGISTER, strings.concatenate({ "r", number_string, "b" }), 0 }
    case 2:
        return { .REGISTER, strings.concatenate({ "r", number_string, "w" }), 0 }
    case 4:
        return { .REGISTER, strings.concatenate({ "r", number_string, "d" }), 0 }
    case 8:
        return { .REGISTER, strings.concatenate({ "r", number_string }), 0 }
    case:
        fmt.println("BUG: Unsupported register size")
        os.exit(1)
    }
}

operand :: proc(location: memory) -> string
{
    switch location.type
    {
    case .IMMEDIATE:
        return location.value
    case .POINTER:
        if location.offset > 0
        {
            buf: [8]byte
            return strings.concatenate({ "[", location.value, " + ", strconv.itoa(buf[:], location.offset), "]" })
        }
        return strings.concatenate({ "[", location.value, "]" })
    case .REGISTER:
        return location.value
    }

    fmt.println("BUG: Unsupported operand")
    os.exit(1)
}

operation_size :: proc(size: int) -> string
{
    switch size
    {
    case 1:
        return "byte"
    case 2:
        return "word"
    case 4:
        return "dword"
    case 8:
        return "qword"
    case:
        fmt.println("BUG: Unsupported operation size")
        os.exit(1)
    }
}
