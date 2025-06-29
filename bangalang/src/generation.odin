package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:strconv"

location_type :: enum
{
    none,
    immediate,
    memory,
    register
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
unknown_reference_type_node: ast_node = { type = .REFERENCE }
extern_param_registers_named: []string = { "di", "si", "dx", "cx" }
extern_param_registers_numbered: []int = { -3, -2 }
syscall_param_registers_named: []string = { "ax", "di", "si", "dx" }
syscall_param_registers_numbered: []int = { -1, -3, -2 }

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

    ctx.data_sizes["[procedure]"] = address_size
    ctx.data_sizes["atomic_i8"] = 1
    ctx.data_sizes["atomic_i16"] = 2
    ctx.data_sizes["atomic_i32"] = 4
    ctx.data_sizes["atomic_i64"] = 8
    ctx.data_sizes["bool"] = 1
    ctx.data_sizes["cint"] = 4 // TODO platform dependant
    ctx.data_sizes["cstring"] = address_size
    ctx.data_sizes["f32"] = 4
    ctx.data_sizes["f64"] = 8
    ctx.data_sizes["i8"] = 1
    ctx.data_sizes["i16"] = 2
    ctx.data_sizes["i32"] = 4
    ctx.data_sizes["i64"] = 8
    ctx.data_sizes["string"] = 8 + address_size

    for &node in nodes
    {
        if node.type == .ASSIGNMENT
        {
            lhs_node := &node.children[0]
            if !is_type(lhs_node) && get_type(lhs_node).value == "[procedure]"
            {
                continue
            }
        }

        generate_statement(file, &node, &ctx)
    }

    fmt.fprintln(file, "  ; default exit")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, 0 ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")

    fmt.fprintln(file, "start_thread:")
    fmt.fprintln(file, "  mov rbx, [rsp + 16] ; copy")
    fmt.fprintln(file, "  mov rcx, [rsp + 8] ; copy")
    fmt.fprintln(file, "  mov [thread_stack + 4096 - 16], rcx ; copy")
    fmt.fprintln(file, "  mov rax, 56 ; syscall: clone")
    fmt.fprintln(file, "  mov rdi, 0x10d00 ; arg0: flags (CLONE_VM | CLONE_FILES | CLONE_SIGHAND | CLONE_THREAD)")
    fmt.fprintln(file, "  mov rsi, thread_stack + 4096 - 16 ; arg1: stack pointer (top of stack)")
    fmt.fprintln(file, "  mov rdx, 0 ; arg2: parent TID ptr (not used)")
    fmt.fprintln(file, "  mov r10, 0 ; arg3: child TID ptr (not used)")
    fmt.fprintln(file, "  mov r8, 0 ; arg4: TLS (not used)")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  cmp rax, 0 ; check if child/zero")
    fmt.fprintln(file, "  jne .end ; skip procedure for parent")
    fmt.fprintln(file, "  call rbx ; call procedure")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, 0 ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, ".end:")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "cmpxchg:")
    fmt.fprintln(file, "  mov rbx, [rsp + 16] ; dereference")
    fmt.fprintln(file, "  mov eax, [rsp + 12] ; copy")
    fmt.fprintln(file, "  mov ecx, [rsp + 8] ; copy")
    fmt.fprintln(file, "  lock cmpxchg [rbx], ecx ; compare and exchange")
    fmt.fprintln(file, "  setz [rsp + 24] ; assign return value")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "panic_out_of_bounds:")
    fmt.fprintln(file, "  mov rax, 1 ; syscall: print")
    fmt.fprintln(file, "  mov rdi, 1 ; arg0: fd (stdout)")
    fmt.fprintln(file, "  mov rsi, panic_out_of_bounds_message ; arg1: buffer")
    fmt.fprintln(file, "  mov rdx, 27 ; arg2: count")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, 1 ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "panic_negative_slice_length:")
    fmt.fprintln(file, "  mov rax, 1 ; syscall: print")
    fmt.fprintln(file, "  mov rdi, 1 ; arg0: fd (stdout)")
    fmt.fprintln(file, "  mov rsi, panic_negative_slice_length_message ; arg1: buffer")
    fmt.fprintln(file, "  mov rdx, 29 ; arg2: count")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, 1 ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")
    fmt.fprintln(file, "  ret ; return")

    for &node in nodes
    {
        if node.type == .ASSIGNMENT
        {
            lhs_node := &node.children[0]
            if !is_type(lhs_node) && get_type(lhs_node).value == "[procedure]"
            {
                generate_procedure(file, &node, &ctx)
            }
        }
    }

    fmt.fprintln(file, "section .bss")
    fmt.fprintln(file, "  thread_stack: resb 4096")

    fmt.fprintln(file, "section .data")
    fmt.fprintln(file, "  f32_sign_mask: dd 0x80000000")
    fmt.fprintln(file, "  f64_sign_mask: dq 0x8000000000000000")
    fmt.fprintln(file, "  panic_out_of_bounds_message: db \"Panic! Index out of bounds\", 10")
    fmt.fprintln(file, "  panic_negative_slice_length_message: db \"Panic! Negative slice length\", 10")
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

generate_procedure :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context)
{
    lhs_node := &node.children[0]
    lhs_type_node := get_type(lhs_node)

    if lhs_type_node.directive == "#extern"
    {
        fmt.fprintfln(file, "extern %s", lhs_node.value)
        return
    }

    procedure_ctx := copy_gen_context(ctx)
    procedure_ctx.in_proc = true

    offset := 0
    params_type_node := lhs_type_node.children[0]
    for param_index := len(params_type_node.children) - 1; param_index >= 0; param_index -= 1
    {
        param_node := &params_type_node.children[param_index]

        procedure_ctx.stack_variable_offsets[param_node.value] = offset
        offset -= byte_size_of(get_type(param_node), &procedure_ctx)
    }

    procedure_ctx.stack_variable_offsets["[return]"] = offset

    fmt.fprintfln(file, "%s:", lhs_node.value)

    // Account for the instruction pointer pushed to the stack by 'call'
    procedure_ctx.stack_size += address_size

    statement_node := &node.children[1]
    generate_statement(file, statement_node, &procedure_ctx, true)

    procedure_ctx.stack_size -= address_size
    close_gen_context(file, ctx, &procedure_ctx, "procedure", false)

    fmt.fprintln(file, "  ret ; return")
}

generate_statement :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, include_end_label := false)
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
    case:
        fmt.fprintln(file, "  ; expression")
        generate_expression(file, node, ctx, {}, 0)
    }

    if node.type != .SCOPE && include_end_label
    {
        fmt.fprintln(file, ".end:")
    }
}

generate_if :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context)
{
    if_index := ctx.if_index
    ctx.if_index += 1

    fmt.fprintfln(file, "; if_%i", if_index)

    expression_node := &node.children[0]
    statement_node := &node.children[1]

    child_index := 2
    else_index := 0
    expression_dest := register(0, get_type_result(get_type(expression_node)), ctx)

    generate_expression(file, expression_node, ctx, expression_dest)
    fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))
    fmt.fprintfln(file, "  je .if_%i_%s ; skip main scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

    generate_statement(file, statement_node, ctx)

    for child_index + 1 < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        generate_expression(file, &node.children[child_index], ctx, expression_dest)
        child_index += 1

        fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))

        buf: [256]byte
        else_with_index := strings.concatenate({ "else_", strconv.itoa(buf[:], else_index) })
        fmt.fprintfln(file, "  je .if_%i_%s ; skip else scope when false/zero", if_index, child_index + 1 < len(node.children) ? else_with_index : "end")

        generate_statement(file, &node.children[child_index], ctx)
        child_index += 1
    }

    if child_index < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        generate_statement(file, &node.children[child_index], ctx)
        child_index += 1
    }

    fmt.fprintfln(file, ".if_%i_end:", if_index)
}

generate_for :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context)
{
    for_ctx := copy_gen_context(ctx, true)

    for_index := for_ctx.for_index
    for_ctx.for_index += 1

    child_index := 0
    child_node := &node.children[child_index]
    child_index += 1

    if child_node.type == .ASSIGNMENT
    {
        generate_assignment(file, child_node, &for_ctx)

        child_node = &node.children[child_index]
        child_index += 1
    }

    fmt.fprintfln(file, ".for_%i:", for_index)

    expression_dest := register(0, get_type_result(get_type(child_node)), &for_ctx)
    generate_expression(file, child_node, &for_ctx, expression_dest)
    fmt.fprintfln(file, "  cmp %s, 0 ; test expression", operand(expression_dest))
    fmt.fprintfln(file, "  je .for_%i_end ; skip for scope when false/zero", for_index)

    child_node = &node.children[child_index]
    child_index += 1

    statement_node := &node.children[len(node.children) - 1]
    generate_statement(file, statement_node, &for_ctx)

    if child_node.type == .ASSIGNMENT
    {
        generate_assignment(file, child_node, &for_ctx)
    }

    fmt.fprintfln(file, "  jmp .for_%i ; back to top", for_index)
    fmt.fprintfln(file, ".for_%i_end:", for_index)

    close_gen_context(file, ctx, &for_ctx, "for", true)
}

generate_scope :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, include_end_label := false)
{
    fmt.fprintln(file, "; scope start")

    scope_ctx := copy_gen_context(ctx, true)

    for &child_node in node.children
    {
        generate_statement(file, &child_node, &scope_ctx)
    }

    if include_end_label
    {
        fmt.fprintln(file, ".end:")
    }

    close_gen_context(file, ctx, &scope_ctx, "scope", true)

    fmt.fprintln(file, "; scope end")
}

generate_return :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; return")

    expression_node := &node.children[0]

    if ctx.in_proc
    {
        variable_position := ctx.stack_size - ctx.stack_variable_offsets["[return]"]
        generate_expression(file, expression_node, ctx, memory("rsp", variable_position))
        fmt.fprintln(file, "  jmp .end ; skip to end")
    }
    else
    {
        expression_type_node := get_type(expression_node)
        generate_expression(file, expression_node, ctx, register("di", expression_type_node, ctx))
        copy(file, immediate(60), register("ax", expression_type_node, ctx), expression_type_node, ctx)
        fmt.fprintln(file, "  syscall ; call kernel")
    }
}

generate_assignment :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context)
{
    lhs_node := &node.children[0]
    if is_type(lhs_node)
    {
        return
    }

    fmt.fprintln(file, "  ; assignment")

    lhs_type_node := get_type(lhs_node)

    if lhs_node.type == .IDENTIFIER && !is_struct_member(lhs_node) && !(lhs_node.value in ctx.stack_variable_offsets)
    {
        allocate(file, byte_size_of(lhs_type_node, ctx), ctx)
        ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size
    }

    dest := generate_primary(file, lhs_node, ctx, 0, false)

    if len(node.children) == 1
    {
        rhs_node := ast_node { type = .NIL }
        append(&rhs_node.children, lhs_type_node^)
        generate_expression(file, &rhs_node, ctx, dest, 1)
    }
    else
    {
        generate_expression(file, &node.children[1], ctx, dest, 1)
    }
}

generate_expression :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, dest: location, register_num: int = 0)
{
    contains_allocations := contains_allocations(node)
    expression_ctx := copy_gen_context(ctx, true)
    dest_1 := generate_expression_1(file, node, &expression_ctx, register_num, contains_allocations)

    close_gen_context(file, ctx, &expression_ctx, "expression", true)

    if dest.type == .none
    {
        return
    }

    type_node_result := get_type_result(get_type(node))
    if node.type == .NIL && dest.type == .memory
    {
        fmt.fprintfln(file, "  lea rdi, %s ; nil: dest", operand(dest))
        fmt.fprintfln(file, "  mov rcx, %i ; nil: count", byte_size_of(type_node_result, &expression_ctx))
        fmt.fprintln(file, "  mov rax, 0 ; nil: value")
        fmt.fprintln(file, "  rep stosb ; nil")
    }
    else
    {
        copy(file, dest_1, dest, type_node_result, &expression_ctx, node.type == .NIL ? "nil" : "")
    }
}

generate_expression_1 :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    _, binary_operator := slice.linear_search(binary_operators, node.type)
    if !binary_operator
    {
        return generate_primary(file, node, ctx, register_num, contains_allocations)
    }

    lhs_node := &node.children[0]
    rhs_node := &node.children[1]

    operand_type_node := get_type_result(get_type(lhs_node))
    result_type_node := get_type(node)

    lhs_register_num := register_num
    rhs_register_num := lhs_register_num + 1

    lhs_location := generate_expression_1(file, lhs_node, ctx, lhs_register_num, contains_allocations)
    rhs_location := generate_expression_1(file, rhs_node, ctx, rhs_register_num, contains_allocations)

    if operand_type_node.value == "bool"
    {
        return generate_expression_bool(file, node, lhs_location, rhs_location, operand_type_node, ctx, register_num, contains_allocations)
    }

    _, float_type := slice.linear_search(float_types, operand_type_node.value)
    if float_type
    {
        return generate_expression_float(file, node, lhs_location, rhs_location, operand_type_node, result_type_node, ctx, register_num, contains_allocations)
    }

    _, atomic_integer_type := slice.linear_search(atomic_integer_types, operand_type_node.value)
    if atomic_integer_type
    {
        return generate_expression_atomic_integer(file, node, lhs_location, rhs_location, operand_type_node, result_type_node, ctx, register_num, contains_allocations)
    }

    _, signed_integer_type := slice.linear_search(signed_integer_types, operand_type_node.value)
    if signed_integer_type
    {
        return generate_expression_signed_integer(file, node, lhs_location, rhs_location, operand_type_node, result_type_node, ctx, register_num, contains_allocations)
    }

    assert(false, "Failed to generate expression")
    return {}
}

generate_expression_bool :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, operand_type_node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    result_location := register(register_num, operand_type_node, ctx)

    lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node, ctx)

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

generate_expression_float :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, operand_type_node: ^ast_node, result_type_node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    precision := precision(byte_size_of(operand_type_node, ctx))

    _, comparison_operator := slice.linear_search(comparison_operators, node.type)
    if comparison_operator
    {
        lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node, ctx)
        result_location := register(register_num, result_type_node, ctx)

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

    result_location := copy_to_register(file, lhs_location, register_num, result_type_node, ctx)

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

generate_expression_atomic_integer :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, operand_type_node: ^ast_node, result_type_node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    result_location := register(register_num, result_type_node, ctx)

    _, comparison_operator := slice.linear_search(comparison_operators, node.type)
    if comparison_operator
    {
        lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node, ctx)

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

    rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, operand_type_node, ctx)

    #partial switch node.type
    {
    case .ADD_ASSIGN:
        result_location = lhs_location
        fmt.fprintfln(file, "  lock xadd %s, %s ; atomic add", operand(result_location), operand(rhs_register_location))
    case .SUBTRACT_ASSIGN:
        result_location = lhs_location
        fmt.fprintfln(file, "  neg %s ; negate", operand(rhs_register_location))
        fmt.fprintfln(file, "  lock xadd %s, %s ; atomic add", operand(result_location), operand(rhs_register_location))
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_expression_signed_integer :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, operand_type_node: ^ast_node, result_type_node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    result_location := register(register_num, result_type_node, ctx)

    _, comparison_operator := slice.linear_search(comparison_operators, node.type)
    if comparison_operator
    {
        lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node, ctx)

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
        result_location = copy_to_register(file, lhs_location, register_num, result_type_node, ctx)
        fmt.fprintfln(file, "  add %s, %s ; add", operand(result_location), operand(rhs_location))
    case .ADD_ASSIGN:
        result_location = lhs_location
        rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, operand_type_node, ctx)
        fmt.fprintfln(file, "  add %s, %s ; add", operand(result_location), operand(rhs_register_location))
    case .SUBTRACT:
        result_location = copy_to_register(file, lhs_location, register_num, result_type_node, ctx)
        fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(result_location), operand(rhs_location))
    case .SUBTRACT_ASSIGN:
        result_location = lhs_location
        rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, operand_type_node, ctx)
        fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(result_location), operand(rhs_register_location))
    case .MULTIPLY:
        result_location = copy_to_register(file, lhs_location, register_num, result_type_node, ctx)
        fmt.fprintfln(file, "  imul %s, %s ; multiply", operand(result_location), operand(rhs_location))
    case .DIVIDE, .MODULO:
        // dividend / divisor
        rhs_register_location := copy_to_non_immediate(file, rhs_location, register_num, result_type_node, ctx)
        output_register := register(node.type == .DIVIDE ? "ax" : "dx", result_type_node, ctx)
        fmt.fprintfln(file, "  mov %s, 0 ; divide: assign zero to dividend high part", operand(register("dx", result_type_node, ctx)))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign lhs to dividend low part", operand(register("ax", result_type_node, ctx)), operand(lhs_location))
        fmt.fprintfln(file, "  idiv %s ; divide", operand(rhs_register_location))
        fmt.fprintfln(file, "  mov %s, %s ; divide: assign result", operand(result_location), operand(output_register))
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_primary :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    type_node := get_type(node)

    #partial switch node.type
    {
    case .REFERENCE:
        primary_dest := generate_primary(file, &node.children[0], ctx, register_num, contains_allocations)
        register_dest := register(register_num, type_node, ctx)
        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(register_dest), operand(primary_dest))
        return register_dest
    case .NEGATE:
        primary_dest := generate_primary(file, &node.children[0], ctx, register_num, contains_allocations)
        register_dest := copy_to_register(file, primary_dest, register_num, type_node, ctx)

        _, float_type := slice.linear_search(float_types, get_type_value(type_node))
        if float_type
        {
            sign_mask_name := strings.concatenate({ get_type_value(type_node), "_sign_mask" })
            sign_mask := copy_to_register(file, memory(sign_mask_name, 0), register_num + 1, type_node, ctx)
            fmt.fprintfln(file, "  xorp%s %s, %s ; negate", precision(byte_size_of(type_node, ctx)), operand(register_dest), operand(sign_mask))
        }
        else
        {
            fmt.fprintfln(file, "  neg %s ; negate", operand(register_dest))
        }

        return register_dest
    case .DEREFERENCE:
        primary_dest := generate_primary(file, &node.children[0], ctx, register_num, contains_allocations)
        register_dest := copy_to_register(file, primary_dest, register_num, &unknown_reference_type_node, ctx, "dereference")
        return memory(operand(register_dest), 0)
    case .INDEX:
        child_location := generate_primary(file, &node.children[0], ctx, register_num, contains_allocations)

        child_type_node := get_type(&node.children[0])

        start_expression_node := &node.children[1]
        start_expression_type_node := get_type(start_expression_node)
        start_expression_location := register(register_num + 1, start_expression_type_node, ctx)
        generate_expression(file, start_expression_node, ctx, start_expression_location, register_num + 1)

        length_location := immediate(1)
        if child_type_node.value == "[array]"
        {
            length_location = immediate(child_type_node.children[1].value)
        }
        else if child_type_node.value == "[slice]"
        {
            length_location = child_location
            length_location.offset += address_size
        }

        if type_node.directive != "#boundless"
        {
            fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(start_expression_location), operand(length_location))
            fmt.fprintln(file, "  jge panic_out_of_bounds ; panic!")
        }

        fmt.fprintfln(file, "  cmp %s, 0 ; compare", operand(start_expression_location))
        fmt.fprintln(file, "  jl panic_out_of_bounds ; panic!")

        if type_node.value != "[slice]" && node.children[1].type == .NUMBER
        {
            data_location := child_location
            if child_type_node.value == "[slice]"
            {
                data_location = copy_to_register(file, data_location, register_num, &unknown_reference_type_node, ctx, "dereference")
                data_location = memory(operand(data_location), 0)
            }

            data_location.offset += strconv.atoi(start_expression_node.value) * byte_size_of(type_node, ctx)
            return data_location
        }

        address_location := register(register_num, &unknown_reference_type_node, ctx)
        offset_location := register(register_num + 2, &unknown_reference_type_node, ctx)
        element_type_node := child_type_node.value == "[array]" || child_type_node.value == "[slice]" ? &child_type_node.children[0] : child_type_node

        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(address_location), operand(child_location))
        fmt.fprintfln(file, "  mov %s, %s ; copy", operand(offset_location), operand(start_expression_location))
        fmt.fprintfln(file, "  imul %s, %s ; multiply by element size", operand(offset_location), operand(immediate(byte_size_of(element_type_node, ctx))))
        fmt.fprintfln(file, "  add %s, %s ; offset", operand(address_location), operand(offset_location))

        if type_node.value == "[slice]"
        {
            allocate(file, byte_size_of(type_node, ctx), ctx)
            slice_address_location := memory("rsp", 0)
            slice_length_location := memory("rsp", address_size)

            copy(file, address_location, slice_address_location, &unknown_reference_type_node, ctx)

            end_expression_node := &node.children[2]
            end_expression_type_node := get_type(end_expression_node)
            end_expression_location := register(register_num + 2, end_expression_type_node, ctx)
            generate_expression(file, end_expression_node, ctx, end_expression_location, register_num + 2)

            if type_node.directive != "#boundless"
            {
                fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(end_expression_location), operand(length_location))
                fmt.fprintln(file, "  jg panic_out_of_bounds ; panic!")
            }

            fmt.fprintfln(file, "  cmp %s, 0 ; compare", operand(end_expression_location))
            fmt.fprintln(file, "  jl panic_out_of_bounds ; panic!")

            fmt.fprintfln(file, "  mov %s, %s ; copy", operand(slice_length_location), operand(end_expression_location))
            fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(slice_length_location), operand(start_expression_location))
            fmt.fprintfln(file, "  cmp qword %s, 0 ; compare", operand(slice_length_location))
            fmt.fprintln(file, "  jl panic_negative_slice_length ; panic!")

            return copy_stack_address(file, ctx, 0, register_num)
        }
        else
        {
            return memory(operand(address_location), 0)
        }
    case .CALL:
        return generate_call(file, node, ctx, register_num, false)
    case .IDENTIFIER:
        if type_node.value == "[procedure]"
        {
            return immediate(node.value)
        }

        child_node := &node.children[0]
        if child_node.type == .IDENTIFIER
        {
            primary_location := generate_primary(file, child_node, ctx, register_num, contains_allocations)

            child_type_node := get_type(child_node)
            for &member_node in child_type_node.children
            {
                if member_node.value == node.value
                {
                    break
                }

                primary_location.offset += byte_size_of(get_type(&member_node), ctx)
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
        if type_node.value == "f32"
        {
            buf: [8]byte
            f32_name := strings.concatenate({ "f32_", strconv.itoa(buf[:], len(ctx.data_section_f32s)) })
            append(&ctx.data_section_f32s, node.value)

            return memory(f32_name, 0)
        }
        else if type_node.value == "f64"
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

generate_call :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, register_num: int, deallocate_return: bool) -> location
{
    name_node := node.children[0]
    type_node := get_type(node)

    params_type_node := type_node.children[0]
    return_type_node := len(type_node.children) == 2 ? &type_node.children[1] : nil

    call_stack_size := 0
    return_only_call_stack_size := 0
    if type_node.directive != "#extern"
    {
        for &param_node in params_type_node.children
        {
            call_stack_size += byte_size_of(get_type(&param_node), ctx)
        }
        if return_type_node != nil
        {
            call_stack_size += byte_size_of(return_type_node, ctx)
            return_only_call_stack_size += byte_size_of(return_type_node, ctx)
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

    if type_node.directive == "#extern"
    {
        for &param_node_from_type, param_index in params_type_node.children
        {
            param_node := &node.children[param_index + 1]

            param_registers_named := name_node.value == "syscall" ? syscall_param_registers_named : extern_param_registers_named
            param_registers_numbered := name_node.value == "syscall" ? syscall_param_registers_numbered : extern_param_registers_numbered

            if param_index < len(param_registers_named)
            {
                generate_expression(file, param_node, ctx, register(param_registers_named[param_index], get_type(&param_node_from_type), ctx), register_num)
            }
            else if param_index < len(param_registers_named) + len(param_registers_numbered)
            {
                generate_expression(file, param_node, ctx, register(param_registers_numbered[param_index - len(param_registers_named)], get_type(&param_node_from_type), ctx), register_num)
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
        for &param_node_from_type, param_index in params_type_node.children
        {
            param_node := &node.children[param_index + 1]

            offset -= byte_size_of(get_type(&param_node_from_type), ctx)
            generate_expression(file, param_node, ctx, memory("rsp", offset), register_num)
        }

        if !deallocate_return
        {
            call_stack_size -= return_only_call_stack_size
        }
    }

    if name_node.value == "syscall"
    {
        fmt.fprintln(file, "  syscall ; call kernal")
    }
    else if name_node.value in ctx.stack_variable_offsets
    {
        variable_position := ctx.stack_size - ctx.stack_variable_offsets[name_node.value]
        fmt.fprintfln(file, "  call %s ; call procedure", operand(memory("rsp", variable_position)))
    }
    else
    {
        fmt.fprintfln(file, "  call %s ; call procedure", name_node.value)
    }

    deallocate(file, call_stack_size, ctx)

    if return_type_node == nil
    {
        return {}
    }

    if type_node.directive == "#extern"
    {
        return register("ax", return_type_node, ctx)
    }
    else
    {
        return copy_stack_address(file, ctx, 0, register_num)
    }
}

copy_to_non_immediate :: proc(file: os.Handle, src: location, number: int, type_node: ^ast_node, ctx: ^gen_context, comment: string = "") -> location
{
    if src.type != .immediate
    {
        return src
    }

    register_dest := register(number, type_node, ctx)
    copy(file, src, register_dest, type_node, ctx, comment)
    return register_dest
}

// TODO review, could change to copy_to_non_immediate in some places
copy_to_register :: proc(file: os.Handle, src: location, number: int, type_node: ^ast_node, ctx: ^gen_context, comment: string = "") -> location
{
    if src.type == .register
    {
        return src
    }

    register_dest := register(number, type_node, ctx)
    copy(file, src, register_dest, type_node, ctx, comment)
    return register_dest
}

copy_stack_address :: proc(file: os.Handle, ctx: ^gen_context, offset: int, register_num: int) -> location
{
    dest := register(register_num, &unknown_reference_type_node, ctx)
    copy(file, register("sp", &unknown_reference_type_node, ctx), dest, &unknown_reference_type_node, ctx, "copy stack address")
    return memory(operand(dest), offset)
}

copy :: proc(file: os.Handle, src: location, dest: location, type_node: ^ast_node, ctx: ^gen_context, comment: string = "")
{
    assert(dest.type != .immediate, "Cannot copy to immediate")

    final_comment := "copy"
    if comment != ""
    {
        final_comment = comment
    }

    if dest == src
    {
        return
    }

    _, float_type := slice.linear_search(float_types, type_node.value)
    byte_size := byte_size_of(type_node, ctx)

    if src.type == .register || dest.type == .register
    {
        if float_type
        {
            fmt.fprintfln(file, "  movs%s %s, %s ; %s", precision(byte_size), operand(dest), operand(src), final_comment)
        }
        else
        {
            fmt.fprintfln(file, "  mov %s, %s ; %s", operand(dest), operand(src), final_comment)
        }
    }
    else if src.type == .immediate
    {
        assert(!float_type, "Cannot copy float from immediate")

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

contains_allocations :: proc(node: ^ast_node) -> bool
{
    if node.type == .INDEX && get_type(node).value != "[slice]"
    {
        return true
    }

    if node.type == .CALL && get_type(node).directive != "#extern"
    {
        return true
    }

    for &child_node in node.children
    {
        if contains_allocations(&child_node)
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
    return { .immediate, strings.clone(strconv.itoa(buf[:], value)), 0 }
}

immediate_string :: proc(value: string) -> location
{
    return { .immediate, value, 0 }
}

memory :: proc(address: string, offset: int) -> location
{
    return { .memory, address, offset  }
}

register :: proc
{
    register_named,
    register_numbered
}

register_named :: proc(name: string, type_node: ^ast_node, ctx: ^gen_context) -> location
{
    _, float_type := slice.linear_search(float_types, type_node.value)
    if float_type
    {
        assert(false, "Unsupported data type")
        return {}
    }

    switch byte_size_of(type_node, ctx)
    {
    case 1:
        if strings.ends_with(name, "x")
        {
            first_char, _ := strings.substring(name, 0, 1)
            return { .register, strings.concatenate({ first_char, "l" }), 0 }
        }
        else
        {
            return { .register, strings.concatenate({ name, "l" }), 0 }
        }
    case 2:
        return { .register, name, 0 }
    case 4:
        return { .register, strings.concatenate({ "e", name }), 0 }
    case 8:
        return { .register, strings.concatenate({ "r", name }), 0 }
    }

    assert(false, "Unsupported register size")
    return {}
}

register_numbered :: proc(number: int, type_node: ^ast_node, ctx: ^gen_context) -> location
{
    _, float_type := slice.linear_search(float_types, type_node.value)
    if float_type
    {
        buf: [2]byte
        number_string := strconv.itoa(buf[:], number)

        return { .register, strings.concatenate({ "xmm", number_string }), 0 }
    }

    buf: [2]byte
    number_string := strconv.itoa(buf[:], number + 11)

    switch byte_size_of(type_node, ctx)
    {
    case 1:
        return { .register, strings.concatenate({ "r", number_string, "b" }), 0 }
    case 2:
        return { .register, strings.concatenate({ "r", number_string, "w" }), 0 }
    case 4:
        return { .register, strings.concatenate({ "r", number_string, "d" }), 0 }
    case 8:
        return { .register, strings.concatenate({ "r", number_string }), 0 }
    }

    assert(false, "Unsupported register size")
    return {}
}

operand :: proc(location: location) -> string
{
    switch location.type
    {
    case .none:
        assert(false, "Unsupported operand")
        return ""
    case .immediate:
        return location.value
    case .memory:
        if location.offset == 0
        {
            return strings.concatenate({ "[", location.value, "]" })
        }

        buf: [8]byte
        return strings.concatenate({ "[", location.value, " + ", strconv.itoa(buf[:], location.offset), "]" })
    case .register:
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

byte_size_of :: proc(type_node: ^ast_node, ctx: ^gen_context) -> int
{
    if type_node.type == .REFERENCE
    {
        return address_size
    }

    if type_node.value == "[array]"
    {
        return byte_size_of(&type_node.children[0], ctx) * strconv.atoi(type_node.children[1].value)
    }

    if type_node.value == "[slice]"
    {
        return address_size + 8
    }

    if type_node.value == "struct"
    {
        byte_size := 0
        for &member_node in type_node.children
        {
            byte_size += byte_size_of(get_type(&member_node), ctx)
        }

        return byte_size
    }

    assert(type_node.value in ctx.data_sizes, "Unsupported byte size")

    return ctx.data_sizes[type_node.value]
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
