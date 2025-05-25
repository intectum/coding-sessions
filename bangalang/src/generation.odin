package main

import "core:fmt"
import "core:os"
import "core:slice"
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
    data_section_f32s: [dynamic]string,
    data_section_f64s: [dynamic]string,
    data_section_strings: [dynamic]string,
    data_section_cstrings: [dynamic]string,

    in_proc: bool,

    stack_size: int,
    stack_variable_offsets: map[string]int,

    if_index: int,
    for_index: int
}

address_size :: 8
unknown_reference: data_type = { name = "", length = 1, is_reference = true }
extern_param_registers_named: []string = { "di", "si", "dx", "cx" }
extern_param_registers_numbered: []int = { -2, -1 }

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
    ctx.data_sizes["cint"] = 4 // TODO platform dependant
    ctx.data_sizes["cstring"] = address_size
    ctx.data_sizes["f32"] = 4
    ctx.data_sizes["f64"] = 8
    ctx.data_sizes["i8"] = 1
    ctx.data_sizes["i16"] = 2
    ctx.data_sizes["i32"] = 4
    ctx.data_sizes["i64"] = 8
    ctx.data_sizes["procedure"] = address_size
    ctx.data_sizes["string"] = 8 + address_size

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
    fmt.fprintln(file, "printb:")
    fmt.fprintln(file, "  mov rax, 1 ; syscall: print")
    fmt.fprintln(file, "  mov rdi, 1 ; arg0: fd (stdout)")
    fmt.fprintln(file, "  mov rsi, [rsp + 16] ; arg1: buffer")
    fmt.fprintln(file, "  mov rdx, [rsp + 8] ; arg2: count")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "clone:")
    fmt.fprintln(file, "  mov rbx, [rsp + 8] ; copy")
    fmt.fprintln(file, "  mov rax, 56 ; syscall: clone")
    fmt.fprintln(file, "  mov rdi, 0x00000011 ; arg0: flags (CLONE_VM | SIGCHLD)")
    fmt.fprintln(file, "  mov rsi, thread_stack + 4096 ; arg1: stack pointer (top of stack)")
    fmt.fprintln(file, "  mov rdx, 0 ; arg2: parent TID ptr (not used)")
    fmt.fprintln(file, "  mov r10, 0 ; arg3: child TID ptr (not used)")
    fmt.fprintln(file, "  mov r8, 0 ; arg4: TLS (not used)")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  cmp rax, 0 ; check if child/zero")
    fmt.fprintln(file, "  jne .end ; skip procedure for parent")
    fmt.fprintln(file, "  call rbx ; call procedure")
    fmt.fprintln(file, ".end:")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "exit:")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, [rsp + 8] ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "wait4:")
    fmt.fprintln(file, "  mov rax, 61 ; syscall: wait4")
    fmt.fprintln(file, "  mov rdi, [rsp + 8] ; arg0: child_pid")
    fmt.fprintln(file, "  mov rsi, 0 ; arg1: status (not used)")
    fmt.fprintln(file, "  mov rdx, 0 ; arg2: options (0)")
    fmt.fprintln(file, "  mov r10, 0 ; arg3: RUSAGE (not used)")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "gettimeofday:")
    fmt.fprintln(file, "  mov rax, 96 ; syscall: gettimeofday")
    fmt.fprintln(file, "  mov rdi, [rsp + 8] ; arg0: exit_code")
    fmt.fprintln(file, "  mov rsi, 0 ; arg1: timezone")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "panic_out_of_bounds:")
    fmt.fprintln(file, "  mov rax, 1 ; syscall: print")
    fmt.fprintln(file, "  mov rdi, 1 ; arg0: fd (stdout)")
    fmt.fprintln(file, "  mov rsi, panic_out_of_bounds_message ; arg1: buffer")
    fmt.fprintln(file, "  mov rdx, 26 ; arg2: count")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, 1 ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    for node in nodes
    {
        if node.type == .PROCEDURE
        {
            generate_procedure(file, node, &ctx)
        }
    }

    fmt.fprintln(file, "section .bss")
    fmt.fprintln(file, "  thread_stack: resb 4096")

    fmt.fprintln(file, "section .data")
    fmt.fprintln(file, "  f32_sign_mask: dd 0x80000000")
    fmt.fprintln(file, "  f64_sign_mask: dq 0x8000000000000000")
    fmt.fprintln(file, "  panic_out_of_bounds_message: dd \"Panic! Index out of bounds\"")
    for data_section_f32, index in ctx.data_section_f32s
    {
        final_f32 := data_section_f32
        if strings.index_rune(final_f32, '.') == -1
        {
            final_f32 = strings.concatenate({ final_f32, "." })
        }
        fmt.fprintfln(file, "  f32_%i: dd %s", index, final_f32)
    }
    for data_section_f64, index in ctx.data_section_f64s
    {
        final_f64 := data_section_f64
        if strings.index_rune(final_f64, '.') == -1
        {
            final_f64 = strings.concatenate({ final_f64, "." })
        }
        fmt.fprintfln(file, "  f64_%i: dq %s", index, final_f64)
    }
    for data_section_string, index in ctx.data_section_strings
    {
        final_string, _ := strings.replace_all(data_section_string, "\\n", "\", 10, \"")
        fmt.fprintfln(file, "  string_%i_data: db %s", index, final_string)
        fmt.fprintfln(file, "  string_%i_data_len: equ $ - string_%i_data", index, index)
        fmt.fprintfln(file, "  string_%i: dq string_%i_data_len, string_%i_data", index, index, index)
    }
    for data_section_cstring, index in ctx.data_section_cstrings
    {
        final_cstring, _ := strings.replace_all(data_section_cstring, "\\n", "\", 10, \"")
        fmt.fprintfln(file, "  cstring_%i: db %s, 0", index, final_cstring[1:])
    }
}

generate_procedure :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    name_node := node.children[0]

    if node.data_type.directive == "#extern"
    {
        fmt.fprintfln(file, "extern %s", name_node.value)
        return
    }

    procedure_ctx := copy_gen_context(ctx)
    procedure_ctx.in_proc = true

    offset := 0
    params_data_type := node.data_type.children[0]
    for param_index := len(params_data_type.children) - 1; param_index >= 0; param_index -= 1
    {
        param_data_type := params_data_type.children[param_index]

        procedure_ctx.stack_variable_offsets[param_data_type.identifier] = offset
        offset -= byte_size_of(param_data_type, &procedure_ctx)
    }

    procedure_ctx.stack_variable_offsets["[return]"] = offset

    fmt.fprintfln(file, "%s:", name_node.value)

    // Account for the instruction pointer pushed to the stack by 'call'
    procedure_ctx.stack_size += address_size

    statement_node := node.children[1]
    generate_statement(file, statement_node, &procedure_ctx, true)

    procedure_ctx.stack_size -= address_size
    close_gen_context(file, ctx, &procedure_ctx, "procedure", false)

    fmt.fprintln(file, "  ret ; return")
}

generate_statement :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, include_end_label := false)
{
    #partial switch node.type
    {
    case .IF:
        generate_if(file, node, ctx)
    case .FOR:
        generate_for(file, node, ctx)
    case .SCOPE:
        generate_scope(file, node, ctx, include_end_label)
    case .RETURN:
        generate_return(file, node, ctx)
    case .ASSIGNMENT:
        generate_assignment(file, node, ctx)
    case .CALL:
        fmt.fprintln(file, "  ; call")
        generate_call(file, node, ctx, 0, true)
    case:
        fmt.println("Failed to generate statement")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }

    if node.type != .SCOPE && include_end_label
    {
        fmt.fprintln(file, ".end:")
    }
}

generate_if :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    if_index := ctx.if_index
    ctx.if_index += 1

    fmt.fprintfln(file, "; if_%i", if_index)

    expression_node := node.children[0]
    statement_node := node.children[1]

    child_index := 2
    else_index := 0
    expression_dest := register(0, expression_node.data_type, ctx)

    generate_expression(file, expression_node, ctx, expression_dest)
    fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))
    fmt.fprintfln(file, "  je .if_%i_%s ; skip main scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

    generate_statement(file, statement_node, ctx)

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

        generate_statement(file, node.children[child_index], ctx)
        child_index += 1
    }

    if child_index < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        generate_statement(file, node.children[child_index], ctx)
        child_index += 1
    }

    fmt.fprintfln(file, ".if_%i_end:", if_index)
}

generate_for :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    for_ctx := copy_gen_context(ctx, true)

    for_index := for_ctx.for_index
    for_ctx.for_index += 1

    child_index := 0
    child_node := node.children[child_index]
    child_index += 1

    if child_node.type == .ASSIGNMENT
    {
        generate_assignment(file, child_node, &for_ctx)

        child_node = node.children[child_index]
        child_index += 1
    }

    fmt.fprintfln(file, ".for_%i:", for_index)

    expression_dest := register(0, child_node.data_type, &for_ctx)
    generate_expression(file, child_node, &for_ctx, expression_dest)
    fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))
    fmt.fprintfln(file, "  je .for_%i_end ; skip for scope when false/zero", for_index)

    child_node = node.children[child_index]
    child_index += 1

    statement_node := node.children[len(node.children) - 1]
    generate_statement(file, statement_node, &for_ctx)

    if child_node.type == .ASSIGNMENT
    {
        generate_assignment(file, child_node, &for_ctx)
    }

    fmt.fprintfln(file, "  jmp .for_%i ; back to top", for_index)
    fmt.fprintfln(file, ".for_%i_end:", for_index)

    close_gen_context(file, ctx, &for_ctx, "for", true)
}

generate_scope :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, include_end_label := false)
{
    fmt.fprintln(file, "; scope start")

    scope_ctx := copy_gen_context(ctx, true)

    for child_node in node.children
    {
        generate_statement(file, child_node, &scope_ctx)
    }

    if include_end_label
    {
        fmt.fprintln(file, ".end:")
    }

    close_gen_context(file, ctx, &scope_ctx, "scope", true)

    fmt.fprintln(file, "; scope end")
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
        generate_expression(file, expression_node, ctx, register("di", expression_node.data_type, ctx))
        copy(file, immediate(60), register("ax", expression_node.data_type, ctx), expression_node.data_type, ctx)
        fmt.fprintln(file, "  syscall ; call kernel")
    }
}

generate_assignment :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; assign")

    lhs_node := node.children[0]

    if !(lhs_node.value in ctx.stack_variable_offsets) && len(lhs_node.children) == 0
    {
        allocate(file, byte_size_of(lhs_node.data_type, ctx), ctx)
        ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size
    }

    dest := generate_primary(file, lhs_node, ctx, 0, false)

    rhs_node := len(node.children) == 2 ? node.children[1] : { type = .NIL, data_type = lhs_node.data_type }
    generate_expression(file, rhs_node, ctx, dest, 1)
}

generate_expression :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, dest: location, register_num: int = 0)
{
    contains_allocations := contains_allocations(node)
    expression_ctx := copy_gen_context(ctx, true)
    dest_1 := generate_expression_1(file, node, &expression_ctx, register_num, contains_allocations)

    close_gen_context(file, ctx, &expression_ctx, "expression", true)

    resolved_data_type := resolve_data_type(node.data_type)
    if node.type == .NIL && dest.type == .MEMORY
    {
        fmt.fprintfln(file, "  lea rdi, %s ; nil: dest", operand(dest))
        fmt.fprintfln(file, "  mov rcx, %i ; nil: count", byte_size_of(resolved_data_type, &expression_ctx))
        fmt.fprintln(file, "  mov rax, 0 ; nil: value")
        fmt.fprintln(file, "  rep stosb ; nil")
    }
    else
    {
        copy(file, dest_1, dest, resolved_data_type, &expression_ctx, node.type == .NIL ? "nil" : "")
    }
}

generate_expression_1 :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    if node.type != .EQUAL && node.type != .NOT_EQUAL && node.type != .LESS_THAN && node.type != .GREATER_THAN && node.type != .LESS_THAN_OR_EQUAL && node.type != .GREATER_THAN_OR_EQUAL && node.type != .ADD && node.type != .SUBTRACT && node.type != .MULTIPLY && node.type != .DIVIDE && node.type != .MODULO
    {
        return generate_primary(file, node, ctx, register_num, contains_allocations)
    }

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    operand_data_type := resolve_data_type(lhs_node.data_type)
    result_data_type := node.data_type

    lhs_register_num := register_num / 2 * 2 + 2
    rhs_register_num := lhs_register_num + 1

    lhs_location := generate_expression_1(file, lhs_node, ctx, lhs_register_num, contains_allocations)
    rhs_location := generate_expression_1(file, rhs_node, ctx, rhs_register_num, contains_allocations)

    if operand_data_type.name == "bool"
    {
        return generate_expression_bool(file, node, lhs_location, rhs_location, operand_data_type, ctx, register_num, contains_allocations)
    }

    _, float_data_type := slice.linear_search(float_data_types, operand_data_type.name)
    if float_data_type
    {
        return generate_expression_float(file, node, lhs_location, rhs_location, operand_data_type, result_data_type, ctx, register_num, contains_allocations)
    }

    _, signed_integer_data_type := slice.linear_search(signed_integer_data_types, operand_data_type.name)
    if signed_integer_data_type
    {
        return generate_expression_signed_integer(file, node, lhs_location, rhs_location, operand_data_type, result_data_type, ctx, register_num, contains_allocations)
    }

    assert(false, "Failed to generate expression")
    return {}
}

generate_expression_bool :: proc(file: os.Handle, node: ast_node, lhs_location: location, rhs_location: location, operand_data_type: data_type, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    result_location := register(register_num, operand_data_type, ctx)

    lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_data_type, ctx)

    fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(lhs_register_location), operand(rhs_location))

    #partial switch node.type
    {
    case .EQUAL:
        fmt.fprintfln(file, "  sete %s ; equal", operand(result_location))
    case .NOT_EQUAL:
        fmt.fprintfln(file, "  setne %s ; not equal", operand(result_location))
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_expression_float :: proc(file: os.Handle, node: ast_node, lhs_location: location, rhs_location: location, operand_data_type: data_type, result_data_type: data_type, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    precision := precision(byte_size_of(operand_data_type, ctx))

    _, comparison_operator := slice.linear_search(comparison_operators, node.type)
    if comparison_operator
    {
        lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_data_type, ctx)
        result_location := register(register_num, result_data_type, ctx)

        fmt.fprintfln(file, "  ucomis%s %s, %s ; compare", precision, operand(lhs_register_location), operand(rhs_location))

        #partial switch node.type
        {
        case .EQUAL:
            fmt.fprintfln(file, "  sete %s ; equal", operand(result_location))
        case .NOT_EQUAL:
            fmt.fprintfln(file, "  setne %s ; not equal", operand(result_location))
        case .LESS_THAN:
            fmt.fprintfln(file, "  setb %s ; less than", operand(result_location))
        case .GREATER_THAN:
            fmt.fprintfln(file, "  seta %s ; greater than", operand(result_location))
        case .LESS_THAN_OR_EQUAL:
            fmt.fprintfln(file, "  setbe %s ; less than or equal", operand(result_location))
        case .GREATER_THAN_OR_EQUAL:
            fmt.fprintfln(file, "  setae %s ; greater than or equal", operand(result_location))
        case:
            assert(false, "Failed to generate expression")
        }

        return result_location
    }

    result_location := copy_to_register(file, lhs_location, register_num, result_data_type, ctx)

    #partial switch node.type
    {
    case .ADD:
        fmt.fprintfln(file, "  adds%s %s, %s ; add", precision, operand(result_location), operand(rhs_location))
    case .SUBTRACT:
        fmt.fprintfln(file, "  subs%s %s, %s ; subtract", precision, operand(result_location), operand(rhs_location))
    case .MULTIPLY:
        fmt.fprintfln(file, "  muls%s %s, %s ; multiply", precision, operand(result_location), operand(rhs_location))
    case .DIVIDE:
        fmt.fprintfln(file, "  divs%s %s, %s ; divide", precision, operand(result_location), operand(rhs_location))
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_expression_signed_integer :: proc(file: os.Handle, node: ast_node, lhs_location: location, rhs_location: location, operand_data_type: data_type, result_data_type: data_type, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    result_location := register(register_num, result_data_type, ctx)

    _, comparison_operator := slice.linear_search(comparison_operators, node.type)
    if comparison_operator
    {
        lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_data_type, ctx)

        fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(lhs_register_location), operand(rhs_location))

        #partial switch node.type
        {
        case .EQUAL:
            fmt.fprintfln(file, "  sete %s ; equal", operand(result_location))
        case .NOT_EQUAL:
            fmt.fprintfln(file, "  setne %s ; not equal", operand(result_location))
        case .LESS_THAN:
            fmt.fprintfln(file, "  setl %s ; less than", operand(result_location))
        case .GREATER_THAN:
            fmt.fprintfln(file, "  setg %s ; greater than", operand(result_location))
        case .LESS_THAN_OR_EQUAL:
            fmt.fprintfln(file, "  setle %s ; less than or equal", operand(result_location))
        case .GREATER_THAN_OR_EQUAL:
            fmt.fprintfln(file, "  setge %s ; greater than or equal", operand(result_location))
        case:
            assert(false, "Failed to generate expression")
        }

        return result_location
    }

    #partial switch node.type
    {
    case .ADD:
        result_location = copy_to_register(file, lhs_location, register_num, result_data_type, ctx)
        fmt.fprintfln(file, "  add %s, %s ; add", operand(result_location), operand(rhs_location))
    case .SUBTRACT:
        result_location = copy_to_register(file, lhs_location, register_num, result_data_type, ctx)
        fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(result_location), operand(rhs_location))
    case .MULTIPLY:
        result_location = copy_to_register(file, lhs_location, register_num, result_data_type, ctx)
        fmt.fprintfln(file, "  imul %s, %s ; multiply", operand(result_location), operand(rhs_location))
    case .DIVIDE, .MODULO:
        // dividend / divisor
        rhs_register_location := copy_to_non_immediate(file, rhs_location, register_num, result_data_type, ctx)
        output_register := register(node.type == .DIVIDE ? "ax" : "dx", result_data_type, ctx)
        fmt.fprintfln(file, "  mov %s, 0 ; divide: assign zero to dividend high part", operand(register("dx", result_data_type, ctx)))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign lhs to dividend low part", operand(register("ax", result_data_type, ctx)), operand(lhs_location))
        fmt.fprintfln(file, "  idiv %s ; divide", operand(rhs_register_location))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign result", operand(result_location), operand(output_register))
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_primary :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    #partial switch node.type
    {
    case .REFERENCE:
        primary_dest := generate_primary(file, node.children[0], ctx, register_num, contains_allocations)
        register_dest := register(register_num, node.data_type, ctx)
        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(register_dest), operand(primary_dest))
        return register_dest
    case .NEGATE:
        primary_dest := generate_primary(file, node.children[0], ctx, register_num, contains_allocations)
        register_dest := copy_to_register(file, primary_dest, register_num, node.data_type, ctx)

        _, float_data_type := slice.linear_search(float_data_types, node.data_type.name)
        if float_data_type
        {
            sign_mask_name := strings.concatenate({ node.data_type.name, "_sign_mask" })
            sign_mask := copy_to_register(file, memory(sign_mask_name, 0), register_num + 1, node.data_type, ctx)
            fmt.fprintfln(file, "  xorp%s %s, %s ; negate", precision(byte_size_of(node.data_type, ctx)), operand(register_dest), operand(sign_mask))
        }
        else
        {
            fmt.fprintfln(file, "  neg %s ; negate", operand(register_dest))
        }

        return register_dest
    case .DEREFERENCE:
        primary_dest := generate_primary(file, node.children[0], ctx, register_num, contains_allocations)
        register_dest := copy_to_register(file, primary_dest, register_num, unknown_reference, ctx, "dereference")
        return memory(operand(register_dest), 0)
    case .INDEX:
        primary_location := generate_primary(file, node.children[0], ctx, register_num, contains_allocations)

        if node.children[1].type == .NUMBER
        {
            primary_location.offset += strconv.atoi(node.children[1].value) * ctx.data_sizes[node.data_type.name]
            return primary_location
        }

        expression_location := register(register_num + 1, node.children[1].data_type, ctx)
        generate_expression(file, node.children[1], ctx, expression_location, register_num + 1)

        if node.data_type.directive != "#boundless"
        {
            fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(expression_location), operand(immediate(node.children[0].data_type.length)))
            fmt.fprintln(file, "  jge panic_out_of_bounds ; panic!")
        }

        fmt.fprintfln(file, "  cmp %s, 0 ; compare", operand(expression_location))
        fmt.fprintln(file, "  jl panic_out_of_bounds ; panic!")

        address_location := register(register_num, unknown_reference, ctx)
        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(address_location), operand(primary_location))
        fmt.fprintfln(file, "  imul %s, %s ; multiply by data size", operand(expression_location), operand(immediate(byte_size_of(node.data_type, ctx))))
        fmt.fprintfln(file, "  add %s, %s ; offset", operand(address_location), operand(expression_location))

        return memory(operand(address_location), 0)
    case .CALL:
        return generate_call(file, node, ctx, register_num, false)
    case .IDENTIFIER:
        if node.data_type.name == "procedure"
        {
            return immediate(node.value)
        }

        if len(node.children) == 1
        {
            primary_location := generate_primary(file, node.children[0], ctx, register_num, contains_allocations)

            for member_data_type in node.children[0].data_type.children
            {
                if member_data_type.identifier == node.value
                {
                    break
                }

                primary_location.offset += byte_size_of(member_data_type, ctx)
            }

            return primary_location
        }

        variable_position := ctx.stack_size - ctx.stack_variable_offsets[node.value]
        if contains_allocations
        {
            return copy_stack_address(file, ctx, variable_position, register_num)
        }
        else
        {
            return memory("rsp", variable_position)
        }
    case .STRING:
        buf: [8]byte
        string_name := strings.concatenate({ "string_", strconv.itoa(buf[:], len(ctx.data_section_strings)) })
        append(&ctx.data_section_strings, node.value)

        return memory(string_name, 0)
    case .CSTRING:
        buf: [8]byte
        cstring_name := strings.concatenate({ "cstring_", strconv.itoa(buf[:], len(ctx.data_section_cstrings)) })
        append(&ctx.data_section_cstrings, node.value)

        return immediate(cstring_name)
    case .NUMBER:
        if node.data_type.name == "f32"
        {
            buf: [8]byte
            f32_name := strings.concatenate({ "f32_", strconv.itoa(buf[:], len(ctx.data_section_f32s)) })
            append(&ctx.data_section_f32s, node.value)

            return memory(f32_name, 0)
        }
        else if node.data_type.name == "f64"
        {
            buf: [8]byte
            f64_name := strings.concatenate({ "f64_", strconv.itoa(buf[:], len(ctx.data_section_f64s)) })
            append(&ctx.data_section_f64s, node.value)

            return memory(f64_name, 0)
        }

        return immediate(node.value)
    case .BOOLEAN:
        return immediate(node.value == "true" ? 1 : 0)
    case .NIL:
        return immediate(0)
    case:
        return generate_expression_1(file, node, ctx, register_num, contains_allocations)
    }
}

generate_call :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int, deallocate_return: bool) -> location
{
    name_node := node.children[0]

    params_data_type := node.data_type.children[0]
    return_data_type := len(node.data_type.children) == 2 ? &node.data_type.children[1] : nil

    call_stack_size := 0
    return_only_call_stack_size := 0
    if node.data_type.directive != "#extern"
    {
        for param_data_type in params_data_type.children
        {
            call_stack_size += byte_size_of(param_data_type, ctx)
        }
        if return_data_type != nil
        {
            call_stack_size += byte_size_of(return_data_type^, ctx)
            return_only_call_stack_size += byte_size_of(return_data_type^, ctx)
        }
    }

    misalignment := (ctx.stack_size + call_stack_size) % 16
    if misalignment != 0
    {
        misalignment = 16 - misalignment
        call_stack_size += misalignment
        return_only_call_stack_size += misalignment
    }

    allocate(file, call_stack_size, ctx)

    if node.data_type.directive == "#extern"
    {
        for param_data_type, param_index in params_data_type.children
        {
            param_node := node.children[param_index + 1]

            if param_index < 4
            {
                generate_expression(file, param_node, ctx, register(extern_param_registers_named[param_index], param_data_type, ctx), register_num)
            }
            else if param_index < 6
            {
                generate_expression(file, param_node, ctx, register(extern_param_registers_numbered[param_index - 4], param_data_type, ctx), register_num)
            }
            else
            {
                assert(false, "Pass by stack not yet supported when calling c")
            }
        }
    }
    else
    {
        offset := call_stack_size - return_only_call_stack_size
        for param_data_type, param_index in params_data_type.children
        {
            param_node := node.children[param_index + 1]

            offset -= byte_size_of(param_data_type, ctx)
            generate_expression(file, param_node, ctx, memory("rsp", offset), register_num)
        }

        if !deallocate_return
        {
            call_stack_size -= return_only_call_stack_size
        }
    }

    if name_node.value in ctx.stack_variable_offsets
    {
        variable_position := ctx.stack_size - ctx.stack_variable_offsets[name_node.value]
        fmt.fprintfln(file, "  call %s ; call procedure", operand(memory("rsp", variable_position)))
    }
    else
    {
        fmt.fprintfln(file, "  call %s ; call procedure", name_node.value)
    }

    deallocate(file, call_stack_size, ctx)

    if return_data_type == nil
    {
        return {}
    }

    if node.data_type.directive == "#extern"
    {
        return register("ax", return_data_type^, ctx)
    }
    else
    {
        return copy_stack_address(file, ctx, 0, register_num)
    }
}

copy_to_non_immediate :: proc(file: os.Handle, src: location, number: int, data_type: data_type, ctx: ^gen_context, comment: string = "") -> location
{
    if src.type != .IMMEDIATE
    {
        return src
    }

    register_dest := register(number, data_type, ctx)
    copy(file, src, register_dest, data_type, ctx, comment)
    return register_dest
}

// TODO review, could change to copy_to_non_immediate in some places
copy_to_register :: proc(file: os.Handle, src: location, number: int, data_type: data_type, ctx: ^gen_context, comment: string = "") -> location
{
    if src.type == .REGISTER
    {
        return src
    }

    register_dest := register(number, data_type, ctx)
    copy(file, src, register_dest, data_type, ctx, comment)
    return register_dest
}

copy_stack_address :: proc(file: os.Handle, ctx: ^gen_context, offset: int, register_num: int) -> location
{
    dest := register(register_num, unknown_reference, ctx)
    copy(file, register("sp", unknown_reference, ctx), dest, unknown_reference, ctx, "copy stack address")
    return memory(operand(dest), offset)
}

copy :: proc(file: os.Handle, src: location, dest: location, data_type: data_type, ctx: ^gen_context, comment: string = "")
{
    assert(dest.type != .IMMEDIATE, "Cannot copy to immediate")

    final_comment := "copy"
    if comment != ""
    {
        final_comment = comment
    }

    if dest == src
    {
        return
    }

    _, float_data_type := slice.linear_search(float_data_types, data_type.name)
    byte_size := byte_size_of(data_type, ctx)

    if src.type == .REGISTER || dest.type == .REGISTER
    {
        if float_data_type && !data_type.is_reference
        {
            fmt.fprintfln(file, "  movs%s %s, %s ; %s", precision(byte_size), operand(dest), operand(src), final_comment)
        }
        else
        {
            fmt.fprintfln(file, "  mov %s, %s ; %s", operand(dest), operand(src), final_comment)
        }
    }
    else if src.type == .IMMEDIATE
    {
        assert(!float_data_type, "Cannot copy float from immediate")

        fmt.fprintfln(file, "  mov %s %s, %s ; %s", operation_size(byte_size), operand(dest), operand(src), final_comment)
    }
    else
    {
        fmt.fprintfln(file, "  lea rsi, %s ; %s: src", operand(src), final_comment);
        fmt.fprintfln(file, "  lea rdi, %s ; %s: dest", operand(dest), final_comment);
        fmt.fprintfln(file, "  mov rcx, %i ; %s: count", byte_size, final_comment);
        fmt.fprintfln(file, "  rep movsb ; %s", final_comment);
    }
}

copy_gen_context := proc(ctx: ^gen_context, inline := false) -> gen_context
{
    ctx_copy: gen_context
    ctx_copy.data_sizes = ctx.data_sizes
    ctx_copy.data_section_f32s = ctx.data_section_f32s
    ctx_copy.data_section_f64s = ctx.data_section_f64s
    ctx_copy.data_section_strings = ctx.data_section_strings
    ctx_copy.data_section_cstrings = ctx.data_section_cstrings
    ctx_copy.in_proc = ctx.in_proc

    if inline
    {
        ctx_copy.stack_size = ctx.stack_size

        for key in ctx.stack_variable_offsets
        {
            ctx_copy.stack_variable_offsets[key] = ctx.stack_variable_offsets[key]
        }

        ctx_copy.if_index = ctx.if_index
        ctx_copy.for_index = ctx.for_index
    }

    return ctx_copy
}

close_gen_context :: proc(file: os.Handle, parent_ctx: ^gen_context, ctx: ^gen_context, name: string, inline: bool)
{
    parent_ctx.data_section_f32s = ctx.data_section_f32s
    parent_ctx.data_section_f64s = ctx.data_section_f64s
    parent_ctx.data_section_strings = ctx.data_section_strings
    parent_ctx.data_section_cstrings = ctx.data_section_cstrings

    if inline
    {
        parent_ctx.if_index = ctx.if_index
        parent_ctx.for_index = ctx.for_index
    }

    stack_size := inline ? ctx.stack_size - parent_ctx.stack_size : ctx.stack_size
    if stack_size > 0
    {
        fmt.fprintfln(file, "  ; close %s", name)
        deallocate(file, stack_size, ctx)
    }
}

contains_allocations :: proc(node: ast_node) -> bool
{
    if node.type == .CALL && node.data_type.directive != "#extern"
    {
        return true
    }

    for child_node in node.children
    {
        if contains_allocations(child_node)
        {
            return true
        }
    }

    return false
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

register_named :: proc(name: string, data_type: data_type, ctx: ^gen_context) -> location
{
    _, float_data_type := slice.linear_search(float_data_types, data_type.name)
    if float_data_type && !data_type.is_reference
    {
        assert(false, "Unsupported data type")
        return {}
    }

    switch byte_size_of(data_type, ctx)
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
    }

    assert(false, "Unsupported register size")
    return {}
}

register_numbered :: proc(number: int, data_type: data_type, ctx: ^gen_context) -> location
{
    _, float_data_type := slice.linear_search(float_data_types, data_type.name)
    if float_data_type && !data_type.is_reference
    {
        buf: [2]byte
        number_string := strconv.itoa(buf[:], number)

        return { .REGISTER, strings.concatenate({ "xmm", number_string }), 0 }
    }

    buf: [2]byte
    number_string := strconv.itoa(buf[:], number + 10)

    switch byte_size_of(data_type, ctx)
    {
    case 1:
        return { .REGISTER, strings.concatenate({ "r", number_string, "b" }), 0 }
    case 2:
        return { .REGISTER, strings.concatenate({ "r", number_string, "w" }), 0 }
    case 4:
        return { .REGISTER, strings.concatenate({ "r", number_string, "d" }), 0 }
    case 8:
        return { .REGISTER, strings.concatenate({ "r", number_string }), 0 }
    }

    assert(false, "Unsupported register size")
    return {}
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

    assert(false, "Unsupported operand")
    return ""
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
    }

    assert(false, "Unsupported operation size")
    return ""
}

precision :: proc(size: int) -> string
{
    switch size
    {
    case 4:
        return "s"
    case 8:
        return "d"
    }

    assert(false, "Unsupported precision")
    return ""
}

byte_size_of :: proc(data_type: data_type, ctx: ^gen_context) -> int
{
    if data_type.is_reference
    {
        return address_size
    }

    if data_type.name == "struct"
    {
        byte_size := 0
        for member_data_type in data_type.children
        {
            byte_size += byte_size_of(member_data_type, ctx)
        }

        return byte_size
    }

    assert(data_type.name in ctx.data_sizes, "Unsupported byte size")

    return ctx.data_sizes[data_type.name] * data_type.length
}

allocate :: proc(file: os.Handle, size: int, ctx: ^gen_context)
{
    if size > 0
    {
        fmt.fprintfln(file, "  sub rsp, %i ; allocate (stack)", size)
        ctx.stack_size += size
    }
}

deallocate :: proc(file: os.Handle, size: int, ctx: ^gen_context)
{
    if size > 0
    {
        fmt.fprintfln(file, "  add rsp, %i ; deallocate (stack)", size)
        ctx.stack_size -= size
    }
}
