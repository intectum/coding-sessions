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

address_size :: 8
data_section_strings: [dynamic]string

generate_program :: proc(file_name: string, nodes: [dynamic]ast_node)
{
    file, file_error := os.open(file_name, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o666)
    if file_error != nil
    {
        fmt.println("Failed to open asm file")
        os.exit(1)
    }
    defer os.close(file)

    fmt.fprintln(file, "section .text")
    fmt.fprintln(file, "global _start")
    fmt.fprintln(file, "_start:")

    ctx: gen_context

    ctx.data_sizes["bool"] = 1
    ctx.data_sizes["i8"] = 1
    ctx.data_sizes["i16"] = 2
    ctx.data_sizes["i32"] = 4
    ctx.data_sizes["i64"] = 8
    ctx.data_sizes["string"] = 16

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

    fmt.fprintln(file, "print:")
    fmt.fprintln(file, "  mov rax, 1 ; syscall: print")
    fmt.fprintln(file, "  mov rdi, 1 ; arg0: fd (stdout)")
    fmt.fprintln(file, "  mov rsi, [rsp + 16] ; arg1: buffer")
    fmt.fprintln(file, "  mov rdx, [rsp + 8] ; arg2: count")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "exit:")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, [rsp + 8] ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    for node in nodes
    {
        if node.type == .PROCEDURE
        {
            generate_procedure(file, node, &ctx)
        }
    }

    fmt.fprintln(file, "section .data")
    for data_section_string, index in data_section_strings
    {
        fmt.fprintfln(file, "  string_%i: db %s", index, data_section_string)
    }
}

generate_procedure :: proc(file: os.Handle, node: ast_node, parent_ctx: ^gen_context)
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    scope_ctx := copy_gen_context(parent_ctx^)
    scope_ctx.in_proc = true

    scope_ctx.stack_size += byte_size_of(node.data_type, scope_ctx)
    scope_ctx.stack_variable_offsets["[return]"] = scope_ctx.stack_size

    for child_index + 1 < len(node.children)
    {
        param_node := node.children[child_index]
        child_index += 1

        scope_ctx.stack_size += byte_size_of(param_node.data_type, scope_ctx)
        scope_ctx.stack_variable_offsets[param_node.value] = scope_ctx.stack_size
    }

    // Account for the instruction pointer pushed to the stack by 'call'
    scope_ctx.stack_size += address_size

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
        generate_call(file, node, ctx, 8, true)
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
    fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))
    fmt.fprintfln(file, "  je .if_%i_%s ; skip main scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

    generate_scope(file, scope_node, ctx)

    for child_index + 1 < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        generate_expression(file, node.children[child_index], ctx, expression_dest)
        child_index += 1

        fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))

        buf: [256]byte
        else_with_index := strings.concatenate({ "else_", strconv.itoa(buf[:], else_index) })
        fmt.fprintfln(file, "  je .if_%i_%s ; skip else scope when false/zero", if_index, child_index + 1 < len(node.children) ? else_with_index : "end")

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
        fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))
        fmt.fprintfln(file, "  je .for_%i_end ; skip for scope when false/zero", for_index)
    }
    else
    {
        fmt.fprintfln(file, ".for_%i:", for_index)

        expression_node := node.children[0]
        expression_dest := register(8, ctx.data_sizes[expression_node.data_type.name])
        generate_expression(file, expression_node, ctx, expression_dest)
        fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))
        fmt.fprintfln(file, "  je .for_%i_end ; skip for scope when false/zero", for_index)
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
        deallocate(file, scope_stack_size, &scope_ctx)
    }

    fmt.fprintln(file, "; scope end")
}

generate_declaration :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; declare")

    lhs_node := node.children[0]

    data_size := byte_size_of(lhs_node.data_type, ctx^)

    allocate(file, data_size, ctx)
    ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size

    if len(node.children) > 1
    {
        rhs_node := node.children[1]

        generate_expression(file, rhs_node, ctx, memory("rsp", 0))
    }
}

generate_assignment :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; assign")

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    variable_position := ctx.stack_size - ctx.stack_variable_offsets[lhs_node.value]
    offset := lhs_node.data_index * ctx.data_sizes[lhs_node.data_type.name]
    if lhs_node.data_type.is_reference
    {
        register_dest := register("bx", address_size)
        copy(file, memory("rsp", variable_position), register_dest, address_size, "dereference")
        generate_expression(file, rhs_node, ctx, memory(operand(register_dest), offset))
    }
    else
    {
        generate_expression(file, rhs_node, ctx, memory("rsp", variable_position + offset))
    }
}

generate_return :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; return")

    expression_node := node.children[0]

    if ctx.in_proc
    {
        variable_position := ctx.stack_size - ctx.stack_variable_offsets["[return]"]
        generate_expression(file, expression_node, ctx, memory("rsp", variable_position))
        fmt.fprintln(file, "  jmp .end ; skip to end")
    }
    else
    {
        data_size := ctx.data_sizes[expression_node.data_type.name]
        generate_expression(file, expression_node, ctx, register("di", data_size))
        copy(file, immediate(60), register("ax", data_size), data_size)
        fmt.fprintln(file, "  syscall ; call kernel")
    }
}

generate_expression :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, dest: location)
{
    expression_ctx := copy_gen_context(ctx^, true)
    dest_1 := generate_expression_1(file, node, &expression_ctx, 8)

    expression_stack_size := expression_ctx.stack_size - ctx.stack_size
    if expression_stack_size > 0
    {
        fmt.fprintln(file, "  ; close expression")
        deallocate(file, expression_stack_size, &expression_ctx)
    }

    copy(file, dest_1, dest, byte_size_of(node.data_type, expression_ctx))
}

generate_expression_1 :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int) -> location
{
    if node.type != .EQUAL && node.type != .NOT_EQUAL && node.type != .LESS_THAN && node.type != .GREATER_THAN && node.type != .LESS_THAN_OR_EQUAL && node.type != .GREATER_THAN_OR_EQUAL && node.type != .ADD && node.type != .SUBTRACT && node.type != .MULTIPLY && node.type != .DIVIDE
    {
        return generate_primary(file, node, ctx, register_num)
    }

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    result_data_size := ctx.data_sizes[node.data_type.name]
    lhs_data_size := ctx.data_sizes[lhs_node.data_type.name]

    lhs_register_num := register_num / 2 * 2 + 2
    rhs_register_num := lhs_register_num + 1

    lhs_dest := generate_expression_1(file, lhs_node, ctx, lhs_register_num)
    rhs_dest := generate_expression_1(file, rhs_node, ctx, rhs_register_num)
    result_dest := register(register_num, result_data_size)

    #partial switch node.type
    {
    case .EQUAL:
        lhs_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  cmp %s, %s ; equal: compare", operand(lhs_dest), operand(rhs_dest))
        fmt.fprintfln(file, "  sete %s ; equal", operand(result_dest))
    case .NOT_EQUAL:
        lhs_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  cmp %s, %s ; not equal: compare", operand(lhs_dest), operand(rhs_dest))
        fmt.fprintfln(file, "  setne %s ; not equal", operand(result_dest))
    case .LESS_THAN:
        lhs_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  cmp %s, %s ; less than: compare", operand(lhs_dest), operand(rhs_dest))
        fmt.fprintfln(file, "  setl %s ; less than", operand(result_dest))
    case .GREATER_THAN:
        lhs_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  cmp %s, %s ; greater than: compare", operand(lhs_dest), operand(rhs_dest))
        fmt.fprintfln(file, "  setg %s ; greater than", operand(result_dest))
    case .LESS_THAN_OR_EQUAL:
        lhs_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  cmp %s, %s ; less than or equal: compare", operand(lhs_dest), operand(rhs_dest))
        fmt.fprintfln(file, "  setle %s ; less than or equal", operand(result_dest))
    case .GREATER_THAN_OR_EQUAL:
        lhs_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  cmp %s, %s ; greater than or equal: compare", operand(lhs_dest), operand(rhs_dest))
        fmt.fprintfln(file, "  setge %s ; greater than or equal", operand(result_dest))
    case .ADD:
        result_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  add %s, %s ; add", operand(result_dest), operand(rhs_dest))
    case .SUBTRACT:
        result_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(result_dest), operand(rhs_dest))
    case .MULTIPLY:
        result_dest = copy_to_register(file, lhs_dest, register_num, lhs_data_size)
        fmt.fprintfln(file, "  imul %s, %s ; multiply", operand(result_dest), operand(rhs_dest))
    case .DIVIDE:
        // dividend / divisor
        fmt.fprintfln(file, "  mov %s, 0 ; divide: assign zero to dividend high part", operand(register("dx", result_data_size)))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign lhs to dividend low part", operand(register("ax", result_data_size)), operand(lhs_dest))
        fmt.fprintfln(file, "  idiv %s ; divide", operand(rhs_dest))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign result", operand(result_dest), operand(register("ax", result_data_size)))
    case:
        fmt.println("BUG: Failed to generate expression")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }

    return result_dest
}

generate_primary :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int) -> location
{
    #partial switch node.type
    {
    case .REFERENCE:
        primary_dest := generate_primary(file, node.children[0], ctx, register_num)
        register_dest := register(register_num, address_size)
        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(register_dest), operand(primary_dest))
        return register_dest
    case .NEGATE:
        primary_dest := generate_primary(file, node.children[0], ctx, register_num)
        register_dest := copy_to_register(file, primary_dest, register_num, ctx.data_sizes[node.data_type.name])
        fmt.fprintfln(file, "  neg %s ; negate", operand(register_dest))
        return register_dest
    case .DEREFERENCE:
        primary_dest := generate_primary(file, node.children[0], ctx, register_num)
        register_dest := copy_to_register(file, primary_dest, register_num, address_size, "dereference")
        return memory(operand(register_dest), 0)
    case .INDEX:
        primary_dest := generate_primary(file, node.children[0], ctx, register_num)
        offset := node.data_index * ctx.data_sizes[node.data_type.name]
        if node.data_type.is_reference
        {
            register_dest := copy_to_register(file, primary_dest, register_num, address_size, "dereference")
            return memory(operand(register_dest), offset)
        }
        else
        {
            primary_dest.offset += offset
            return primary_dest
        }
    case .CALL:
        return generate_call(file, node, ctx, register_num, false)
    case .IDENTIFIER:
        variable_position := ctx.stack_size - ctx.stack_variable_offsets[node.value]

        dest := register(register_num, address_size)
        copy(file, register("sp", address_size), dest, address_size)
        return memory(operand(dest), variable_position)
    case .STRING:
        allocate(file, ctx.data_sizes[node.data_type.name], ctx)

        copy(file, immediate(len(node.value) - 2), memory("rsp", 0), 8)

        buf: [8]byte
        string_name := strings.concatenate({ "string_", strconv.itoa(buf[:], len(data_section_strings)) })
        copy(file, immediate(string_name), memory("rsp", 8), address_size)

        append(&data_section_strings, node.value)

        dest := register(register_num, address_size)
        copy(file, register("sp", address_size), dest, address_size)
        return memory(operand(dest), 0)
    case .NUMBER:
        return immediate(node.value)
    case .BOOLEAN:
        return immediate(node.value == "true" ? 1 : 0)
    case:
        return generate_expression_1(file, node, ctx, register_num)
    }
}

generate_call :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int, deallocate_return: bool) -> location
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    call_stack_size := 0
    return_byte_size := byte_size_of(node.data_type, ctx^)
    allocate(file, return_byte_size, ctx)
    if deallocate_return
    {
        call_stack_size += return_byte_size
    }

    for child_index < len(node.children)
    {
        param_node := node.children[child_index]
        child_index += 1

        param_byte_size := byte_size_of(param_node.data_type, ctx^)
        allocate(file, param_byte_size, ctx)
        call_stack_size += param_byte_size

        generate_expression(file, param_node, ctx, memory("rsp", 0))
    }

    fmt.fprintfln(file, "  call %s ; call procedure", name_node.value)

    deallocate(file, call_stack_size, ctx)

    dest := register(register_num, address_size)
    copy(file, register("sp", address_size), dest, address_size)
    return memory(operand(dest), 0)
}

copy_to_register :: proc(file: os.Handle, src: location, number: int, size: int, comment: string = "") -> location
{
    if src.type == .REGISTER
    {
        return src
    }

    register_dest := register(number, size)
    copy(file, src, register_dest, size, comment)
    return register_dest
}

copy :: proc(file: os.Handle, src: location, dest: location, size: int, comment: string = "")
{
    final_comment := "copy"
    if comment != ""
    {
        final_comment = comment
    }

    if dest.type == .IMMEDIATE
    {
        fmt.println("BUG: Cannot move to immediate")
        os.exit(1)
    }

    if dest == src
    {
        return
    }

    if src.type == .REGISTER || dest.type == .REGISTER
    {
        fmt.fprintfln(file, "  mov %s, %s ; %s", operand(dest), operand(src), final_comment)
    }
    else if src.type == .IMMEDIATE
    {
        fmt.fprintfln(file, "  mov %s %s, %s ; %s", operation_size(size), operand(dest), operand(src), final_comment)
    }
    else
    {
        fmt.fprintfln(file, "  lea rsi, %s ; %s: src", operand(src), final_comment);
        fmt.fprintfln(file, "  lea rdi, %s ; %s: dest", operand(dest), final_comment);
        fmt.fprintfln(file, "  mov rcx, %i ; %s: count", size, final_comment);
        fmt.fprintfln(file, "  rep movsb ; %s", final_comment);
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

immediate :: proc
{
    immediate_int,
    immediate_string
}

immediate_int :: proc(value: int) -> location
{
    buf: [8]byte
    return { .IMMEDIATE, strings.clone(strconv.itoa(buf[:], value)), 0 }
}

immediate_string :: proc(value: string) -> location
{
    return { .IMMEDIATE, value, 0 }
}

memory :: proc(address: string, offset: int) -> location
{
    return { .MEMORY, address, offset  }
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

byte_size_of :: proc(data_type: data_type, ctx: gen_context) -> int
{
    if data_type.is_reference
    {
        return address_size
    }

    return ctx.data_sizes[data_type.name] * data_type.length
}

allocate :: proc(file: os.Handle, size: int, ctx: ^gen_context)
{
    fmt.fprintfln(file, "  sub rsp, %i ; allocate (stack)", size)
    ctx.stack_size += size
}

deallocate :: proc(file: os.Handle, size: int, ctx: ^gen_context)
{
    fmt.fprintfln(file, "  add rsp, %i ; deallocate (stack)", size)
    ctx.stack_size -= size
}
