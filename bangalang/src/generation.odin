package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

location_type :: enum
{
    IMMEDIATE,
    MEMORY,
    REGISTER
}

location :: struct
{
    type: location_type,
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

        scope_ctx.stack_size += scope_ctx.data_sizes[param_node.data_type.name] * param_node.data_type.length
        scope_ctx.stack_variable_offsets[param_node.value] = scope_ctx.stack_size
    }

    scope_ctx.stack_size += scope_ctx.data_sizes[node.data_type.name] * node.data_type.length
    scope_ctx.stack_variable_offsets["[return]"] = scope_ctx.stack_size

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
        generate_call(file, node, ctx, {})
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
    expression_dest := register(8, ctx.data_sizes[expression_node.data_type.name])

    generate_expression(file, expression_node, ctx, expression_dest)
    fmt.fprintfln(file, "  test %s, %s ; test expression", operand(expression_dest), operand(expression_dest))
    fmt.fprintfln(file, "  jz .if_%i_%s ; skip main scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

    generate_scope(file, scope_node, ctx)

    for child_index + 1 < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        generate_expression(file, node.children[child_index], ctx, expression_dest)
        child_index += 1

        fmt.fprintfln(file, "  test %s, %s ; test expression", operand(expression_dest), operand(expression_dest))

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
        expression_dest := register(8, ctx.data_sizes[expression_node.data_type.name])
        generate_expression(file, expression_node, ctx, expression_dest)
        fmt.fprintfln(file, "  test %s, %s ; test expression", operand(expression_dest), operand(expression_dest))
        fmt.fprintfln(file, "  jz .for_%i_end ; skip for scope when false/zero", for_index)
    }
    else
    {
        fmt.fprintfln(file, ".for_%i:", for_index)

        expression_node := node.children[0]
        expression_dest := register(8, ctx.data_sizes[expression_node.data_type.name])
        generate_expression(file, expression_node, ctx, expression_dest)
        fmt.fprintfln(file, "  test %s, %s ; test expression", operand(expression_dest), operand(expression_dest))
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

        generate_expression(file, rhs_node, ctx, { .MEMORY, "rsp", 0 })
    }
}

generate_assignment :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; assign")

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    data_size := ctx.data_sizes[lhs_node.data_type.name] * lhs_node.data_type.length

    variable_position := ctx.stack_size - ctx.stack_variable_offsets[lhs_node.value]
    offset := variable_position + lhs_node.data_index * ctx.data_sizes[lhs_node.data_type.name]
    generate_expression(file, rhs_node, ctx, { .MEMORY, "rsp", offset })
}

generate_return :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; return")

    expression_node := node.children[0]

    if ctx.in_proc
    {
        variable_position := ctx.stack_size - ctx.stack_variable_offsets["[return]"]
        generate_expression(file, expression_node, ctx, { .MEMORY, "rsp", variable_position })
        fmt.fprintln(file, "  jmp .end ; skip to end")
    }
    else
    {
        data_size := ctx.data_sizes[expression_node.data_type.name]
        generate_expression(file, expression_node, ctx, register("di", data_size))
        copy(file, { .IMMEDIATE, "60", 0 }, register("ax", data_size), data_size)
        fmt.fprintln(file, "  syscall ; call kernel")
    }
}

generate_expression :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, dest: location)
{
    dest_1 := generate_expression_1(file, node, ctx, dest, 8)

    data_size := ctx.data_sizes[node.data_type.name] * node.data_type.length
    copy(file, dest_1, dest, data_size)
}

generate_expression_1 :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, dest: location, register_num: int) -> location
{
    if node.type != .ADD && node.type != .SUBTRACT && node.type != .MULTIPLY && node.type != .DIVIDE
    {
        return generate_primary(file, node, ctx, dest, register_num)
    }

    data_size := ctx.data_sizes[node.data_type.name]

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    lhs_register_num := register_num / 2 * 2 + 2
    rhs_register_num := lhs_register_num + 1

    lhs_dest := generate_expression_1(file, lhs_node, ctx, dest, lhs_register_num)
    rhs_dest := generate_expression_1(file, rhs_node, ctx, dest, rhs_register_num)
    final_dest := move_to_register(file, lhs_dest, register_num, data_size)

    #partial switch node.type
    {
    case .ADD:
        fmt.fprintfln(file, "  add %s, %s ; add", operand(final_dest), operand(rhs_dest))
    case .SUBTRACT:
        fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(final_dest), operand(rhs_dest))
    case .MULTIPLY:
        fmt.fprintfln(file, "  imul %s, %s ; multiply", operand(final_dest), operand(rhs_dest))
    case .DIVIDE:
        // dividend / divisor
        fmt.fprintfln(file, "  mov %s, 0 ; divide: assign zero to dividend high part", operand(register("dx", data_size)))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign lhs to dividend low part", operand(register("ax", data_size)), operand(lhs_dest))
        fmt.fprintfln(file, "  idiv %s ; divide: do it!", operand(rhs_dest))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign result", operand(final_dest), operand(register("ax", data_size)))
    case:
        fmt.println("BUG: Failed to generate expression")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }

    return final_dest
}

generate_primary :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, dest: location, register_num: int) -> location
{
    #partial switch node.type
    {
    case .CALL:
        generate_call(file, node, ctx, dest)
        return dest
    case .IDENTIFIER:
        variable_position := ctx.stack_size - ctx.stack_variable_offsets[node.value]
        offset := variable_position + node.data_index * ctx.data_sizes[node.data_type.name]
        return { .MEMORY, "rsp", offset }
    case .NUMBER:
        return { .IMMEDIATE, node.value, 0 }
    case .NEGATE:
        primary_dest := generate_primary(file, node.children[0], ctx, dest, register_num)
        register_dest := move_to_register(file, primary_dest, register_num, ctx.data_sizes[node.data_type.name])
        fmt.fprintfln(file, "  neg %s ; negate", operand(register_dest))
        return register_dest
    case:
        return generate_expression_1(file, node, ctx, dest, register_num)
    }
}

generate_call :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, dest: location)
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    call_stack_size := 0
    for child_index < len(node.children)
    {
        param_node := node.children[child_index]
        child_index += 1

        param_data_size := ctx.data_sizes[param_node.data_type.name] * param_node.data_type.length

        fmt.fprintfln(file, "  sub rsp, %i ; allocate space in stack", param_data_size)
        ctx.stack_size += param_data_size
        call_stack_size += param_data_size

        generate_expression(file, param_node, ctx, { .MEMORY, "rsp", 0 })
    }

    return_data_size := ctx.data_sizes[node.data_type.name] * node.data_type.length
    fmt.fprintfln(file, "  sub rsp, %i ; allocate space in stack", return_data_size)
    ctx.stack_size += return_data_size
    call_stack_size += return_data_size

    fmt.fprintfln(file, "  call %s ; call procedure", name_node.value)

    fmt.fprintfln(file, "  add rsp, %i ; clear params from stack", call_stack_size)
    ctx.stack_size -= call_stack_size

    if dest.value != ""
    {
        copy(file, { .MEMORY, "rsp", -call_stack_size }, dest, return_data_size)
    }
}

move_to_register :: proc(file: os.Handle, src: location, number: int, size: int) -> location
{
    if src.type == .REGISTER
    {
        return src
    }

    register_dest := register(number, size)
    copy(file, src, register_dest, size)
    return register_dest
}

copy :: proc(file: os.Handle, src: location, dest: location, size: int)
{
    if dest.type == .IMMEDIATE
    {
        fmt.println("BUG: Cannot move to immediate")
        os.exit(1)
    }

    if dest == src
    {
        // Nothing to do!
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

register_named :: proc(name: string, size: int) -> location
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

register_numbered :: proc(number: int, size: int) -> location
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

operand :: proc(location: location) -> string
{
    switch location.type
    {
    case .IMMEDIATE:
        return location.value
    case .MEMORY:
        if location.offset == 0
        {
            return strings.concatenate({ "[", location.value, "]" })
        }

        buf: [8]byte
        return strings.concatenate({ "[", location.value, " + ", strconv.itoa(buf[:], location.offset), "]" })
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
