package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

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
    data_section_f32s: [dynamic]string,
    data_section_f64s: [dynamic]string,
    data_section_strings: [dynamic]string,
    data_section_cstrings: [dynamic]string,

    in_proc: bool,

    stack_size: int,
    stack_variable_offsets: map[string]int,

    label_index: int
}

address_size :: 8
index_type_node := ast_node { type = .type, value = "i64" }
unknown_reference_type_node: ast_node = { type = .reference }
extern_param_registers_named: []string = { "di", "si", "dx", "cx" }
extern_param_registers_numbered: []int = { -3, -2 }
syscall_param_registers_named: []string = { "ax", "di", "si", "dx" }
syscall_param_registers_numbered: []int = { -1, -3, -2 }

generate_program :: proc(module: ^module, asm_path: string)
{
    file, file_error := os.open(asm_path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o666)
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

    generate_statements(file, module, &ctx)

    fmt.fprintln(file, "  ; default exit")
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, 0 ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")

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

    generate_procedures(file, module, &ctx)

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
        fmt.fprintfln(file, "  string_%i: dq string_%i_data, string_%i_data_len", index, index, index)
    }
    for data_section_cstring, index in ctx.data_section_cstrings
    {
        final_cstring, _ := strings.replace_all(data_section_cstring, "\\n", "\", 10, \"")
        fmt.fprintfln(file, "  cstring_%i: db %s, 0", index, final_cstring)
    }
}

generate_procedures :: proc(file: os.Handle, module: ^module, ctx: ^gen_context)
{
    for reference in module.ctx.references
    {
        module := &imported_modules[module.ctx.references[reference]]
        generate_procedures(file, module, ctx)
    }

    for &node in module.nodes
    {
        if node.type == .assignment
        {
            lhs_node := &node.children[0]
            lhs_type_node := get_type(lhs_node)
            if !is_type(lhs_node) && lhs_type_node.value == "[procedure]" && lhs_type_node.allocator == "static"
            {
                generate_procedure(file, &node, ctx)
            }
        }
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
        offset -= byte_size_of(get_type(param_node))
    }

    procedure_ctx.stack_variable_offsets["[return]"] = offset

    fmt.fprintfln(file, "%s:", lhs_node.value)

    // Account for the instruction pointer pushed to the stack by 'call'
    procedure_ctx.stack_size += address_size

    rhs_node := &node.children[2]
    generate_statement(file, rhs_node, &procedure_ctx, true)

    procedure_ctx.stack_size -= address_size
    close_gen_context(file, ctx, &procedure_ctx, "procedure", false)

    fmt.fprintln(file, "  ret ; return")
}

generate_statements :: proc(file: os.Handle, module: ^module, ctx: ^gen_context)
{
    for reference in module.ctx.references
    {
        module := &imported_modules[module.ctx.references[reference]]
        generate_statements(file, module, ctx)
    }

    for &node in module.nodes
    {
        if node.type == .assignment
        {
            lhs_node := &node.children[0]
            lhs_type_node := get_type(lhs_node)
            if !is_type(lhs_node) && lhs_type_node.value == "[procedure]" && lhs_type_node.allocator == "static"
            {
                continue
            }
        }

        generate_statement(file, &node, ctx)
    }
}

generate_statement :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, include_end_label := false)
{
    #partial switch node.type
    {
    case .if_:
        generate_if(file, node, ctx)
    case .for_:
        generate_for(file, node, ctx)
    case .return_:
        generate_return(file, node, ctx)
    case .scope:
        generate_scope(file, node, ctx, include_end_label)
    case .assignment:
        generate_assignment(file, node, ctx)
    case:
        fmt.fprintln(file, "  ; expression")
        generate_expression(file, node, ctx)
    }

    if node.type != .scope && include_end_label
    {
        fmt.fprintln(file, ".end:")
    }
}

generate_if :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context)
{
    if_index := ctx.label_index
    ctx.label_index += 1

    fmt.fprintfln(file, "; if_%i", if_index)

    expression_node := &node.children[0]
    statement_node := &node.children[1]

    child_index := 2
    else_index := 0
    expression_type_node := get_type(expression_node)
    expression_operation_size := operation_size(byte_size_of(expression_type_node))

    expression_location := generate_expression(file, expression_node, ctx)
    expression_location = copy_to_non_immediate(file, expression_location, 0, expression_type_node)
    fmt.fprintfln(file, "  cmp %s %s, 0 ; test expression", expression_operation_size, operand(expression_location))
    fmt.fprintfln(file, "  je .if_%i_%s ; skip if scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

    generate_statement(file, statement_node, ctx)

    for child_index + 1 < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else if scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        expression_location = generate_expression(file, &node.children[child_index], ctx)
        expression_location = copy_to_non_immediate(file, expression_location, 0, expression_type_node)
        child_index += 1

        fmt.fprintfln(file, "  cmp %s %s, 0 ; test expression", expression_operation_size, operand(expression_location))

        buf: [256]byte
        else_with_index := strings.concatenate({ "else_", strconv.itoa(buf[:], else_index) })
        fmt.fprintfln(file, "  je .if_%i_%s ; skip else if scope when false/zero", if_index, child_index + 1 < len(node.children) ? else_with_index : "end")

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

    for_index := for_ctx.label_index
    for_ctx.label_index += 1

    child_index := 0
    child_node := &node.children[child_index]
    child_index += 1

    _, statement := slice.linear_search(statement_node_types, child_node.type)
    if statement
    {
        generate_assignment(file, child_node, &for_ctx)

        child_node = &node.children[child_index]
        child_index += 1
    }

    fmt.fprintfln(file, ".for_%i:", for_index)

    expression_type_node := get_type(child_node)
    expression_operation_size := operation_size(byte_size_of(expression_type_node))

    expression_location := generate_expression(file, child_node, &for_ctx)
    expression_location = copy_to_non_immediate(file, expression_location, 0, expression_type_node)
    fmt.fprintfln(file, "  cmp %s %s, 0 ; test expression", expression_operation_size, operand(expression_location))
    fmt.fprintfln(file, "  je .for_%i_end ; skip for scope when false/zero", for_index)

    child_node = &node.children[child_index]
    child_index += 1

    statement_node := &node.children[len(node.children) - 1]
    generate_statement(file, statement_node, &for_ctx)

    if len(node.children) > child_index
    {
        generate_statement(file, child_node, &for_ctx)
    }

    fmt.fprintfln(file, "  jmp .for_%i ; back to top", for_index)
    fmt.fprintfln(file, ".for_%i_end:", for_index)

    close_gen_context(file, ctx, &for_ctx, "for", true)
}

generate_return :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; return")

    if ctx.in_proc
    {
        if len(node.children) > 0
        {
            expression_node := &node.children[0]
            expression_type_node := get_type(expression_node)

            expression_location := generate_expression(file, expression_node, ctx)

            variable_position := ctx.stack_size - ctx.stack_variable_offsets["[return]"]
            return_location := memory("rsp", variable_position)

            copy(file, expression_location, return_location, expression_type_node)
        }

        fmt.fprintln(file, "  jmp .end ; skip to end")
    }
    else
    {
        expression_node := &node.children[0]
        expression_type_node := get_type(expression_node)

        expression_location := generate_expression(file, expression_node, ctx)

        syscall_num_location := register("ax", expression_type_node)
        exit_code_location := register("di", expression_type_node)

        copy(file, immediate(60), syscall_num_location, expression_type_node)
        copy(file, expression_location, exit_code_location, expression_type_node)

        fmt.fprintln(file, "  syscall ; call kernel")
    }
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

generate_assignment :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context)
{
    lhs_node := &node.children[0]
    if is_type(lhs_node)
    {
        return
    }

    lhs_type_node := get_type(lhs_node)
    if lhs_type_node.value == "[module]"
    {
        return
    }

    fmt.fprintln(file, "  ; assignment")

    if lhs_node.type == .identifier && !is_member(lhs_node) && !(lhs_node.value in ctx.stack_variable_offsets)
    {
        allocate(file, byte_size_of(lhs_type_node), ctx)
        ctx.stack_variable_offsets[lhs_node.value] = ctx.stack_size
    }

    lhs_location := generate_primary(file, lhs_node, ctx, 0, false)

    if len(node.children) == 1
    {
        nilify(file, lhs_location, lhs_type_node)
    }
    else
    {
        operator_node := &node.children[1]
        rhs_node := &node.children[2]

        rhs_location := generate_expression(file, rhs_node, ctx, 1)

        if operator_node.type == .assign
        {
            copy(file, rhs_location, lhs_location, lhs_type_node)
        }
        else
        {
            _, float_type := slice.linear_search(float_types, lhs_type_node.value)
            _, atomic_integer_type := slice.linear_search(atomic_integer_types, lhs_type_node.value)
            _, signed_integer_type := slice.linear_search(signed_integer_types, lhs_type_node.value)

            if float_type
            {
                generate_assignment_float(file, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
            }
            else if lhs_type_node.value == "[array]" || lhs_type_node.value == "[slice]"
            {
                generate_assignment_float_array(file, operator_node, lhs_location, rhs_location, lhs_type_node, ctx, 2)
            }
            else if atomic_integer_type
            {
                generate_assignment_atomic_integer(file, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
            }
            else if signed_integer_type
            {
                generate_assignment_signed_integer(file, operator_node, lhs_location, rhs_location, lhs_type_node, 2)
            }
            else
            {
                assert(false, "Failed to generate assignment")
            }
        }
    }
}

generate_assignment_float :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, type_node: ^ast_node, register_num: int)
{
    precision := precision(byte_size_of(type_node))
    result_location := copy_to_register(file, lhs_location, register_num, type_node)

    #partial switch node.type
    {
    case .add_assign:
        fmt.fprintfln(file, "  adds%s %s, %s ; add assign", precision, operand(result_location), operand(rhs_location))
    case .subtract_assign:
        fmt.fprintfln(file, "  subs%s %s, %s ; subtract assign", precision, operand(result_location), operand(rhs_location))
    case .multiply_assign:
        fmt.fprintfln(file, "  muls%s %s, %s ; multiply assign", precision, operand(result_location), operand(rhs_location))
    case .divide_assign:
        fmt.fprintfln(file, "  divs%s %s, %s ; divide assign", precision, operand(result_location), operand(rhs_location))
    case:
        assert(false, "Failed to generate assignment")
    }

    copy(file, result_location, lhs_location, type_node)
}

generate_assignment_float_array :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, type_node: ^ast_node, ctx: ^gen_context, register_num: int)
{
    lhs_location := lhs_location
    rhs_location := rhs_location

    element_type_node := &type_node.children[0]
    element_size := byte_size_of(element_type_node)
    precision := precision(element_size)

    lhs_register_location := register(register_num, element_type_node)
    rhs_register_location := register(register_num + 1, element_type_node)

    length_location := get_length_location(type_node, lhs_location)
    if length_location.type == .immediate
    {
        length := strconv.atoi(length_location.value)
        if length <= 4
        {
            fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, operand(lhs_register_location), operand(lhs_location))
            fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, operand(rhs_register_location), operand(rhs_location))

            #partial switch node.type
            {
            case .add_assign:
                fmt.fprintfln(file, "  addp%s %s, %s ; add assign", precision, operand(lhs_register_location), operand(rhs_register_location))
            case .subtract_assign:
                fmt.fprintfln(file, "  subp%s %s, %s ; subtract assign", precision, operand(lhs_register_location), operand(rhs_register_location))
            case .multiply_assign:
                fmt.fprintfln(file, "  mulp%s %s, %s ; multiply assign", precision, operand(lhs_register_location), operand(rhs_register_location))
            case .divide_assign:
                fmt.fprintfln(file, "  divp%s %s, %s ; divide assign", precision, operand(lhs_register_location), operand(rhs_register_location))
            case:
                assert(false, "Failed to generate assignment")
            }

            if length == 4
            {
                fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, operand(lhs_location), operand(lhs_register_location))
            }
            else
            {
                limit := lhs_location
                limit.offset += (length - 1) * element_size

                for lhs_location.offset <= limit.offset
                {
                    fmt.fprintfln(file, "  movs%s %s, %s ; copy", precision, operand(lhs_location), operand(lhs_register_location))
                    if lhs_location.offset < limit.offset
                    {
                        fmt.fprintfln(file, "  shufp%s %s, %s, 0x39 ; shuffle", precision, operand(lhs_register_location), operand(lhs_register_location))
                    }

                    lhs_location.offset += element_size
                }
            }

            return
        }
    }

    vector_assign_index := ctx.label_index
    ctx.label_index += 1

    lhs_address_location := register(register_num, &unknown_reference_type_node)
    if type_node.value == "[array]"
    {
        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(lhs_address_location), operand(lhs_location))
    }
    else
    {
        copy(file, lhs_location, lhs_address_location, &unknown_reference_type_node)
    }
    lhs_location = memory(operand(lhs_address_location), 0)

    rhs_address_location := register(register_num + 1, &unknown_reference_type_node)
    if type_node.value == "[array]"
    {
        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(rhs_address_location), operand(rhs_location))
    }
    else
    {
        copy(file, rhs_location, rhs_address_location, &unknown_reference_type_node)
    }
    rhs_location = memory(operand(rhs_address_location), 0)

    limit_location := register(register_num + 2, &index_type_node)
    copy(file, length_location, limit_location, &index_type_node)
    fmt.fprintfln(file, "  sub %s, 4 ; subtract", operand(limit_location))
    fmt.fprintfln(file, "  imul %s, %s ; multiply", operand(limit_location), operand(immediate(element_size)))
    fmt.fprintfln(file, "  add %s, %s ; add", operand(limit_location), operand(lhs_address_location))

    fmt.fprintfln(file, "vector_assign_multi_loop_%i:", vector_assign_index)
    fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, operand(lhs_register_location), operand(lhs_location))
    fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, operand(rhs_register_location), operand(rhs_location))

    #partial switch node.type
    {
    case .add_assign:
        fmt.fprintfln(file, "  addp%s %s, %s ; add assign", precision, operand(lhs_register_location), operand(rhs_register_location))
    case .subtract_assign:
        fmt.fprintfln(file, "  subp%s %s, %s ; subtract assign", precision, operand(lhs_register_location), operand(rhs_register_location))
    case .multiply_assign:
        fmt.fprintfln(file, "  mulp%s %s, %s ; multiply assign", precision, operand(lhs_register_location), operand(rhs_register_location))
    case .divide_assign:
        fmt.fprintfln(file, "  divp%s %s, %s ; divide assign", precision, operand(lhs_register_location), operand(rhs_register_location))
    case:
        assert(false, "Failed to generate assignment")
    }

    fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(lhs_address_location), operand(limit_location))
    fmt.fprintfln(file, "  jg vector_assign_single_%i ; skip to single loop", vector_assign_index)

    fmt.fprintfln(file, "  movup%s %s, %s ; copy", precision, operand(lhs_location), operand(lhs_register_location))
    fmt.fprintfln(file, "  add %s, %s ; add", operand(lhs_address_location), operand(immediate(4 * element_size)))
    fmt.fprintfln(file, "  add %s, %s ; add", operand(rhs_address_location), operand(immediate(4 * element_size)))
    fmt.fprintfln(file, "  jmp vector_assign_multi_loop_%i", vector_assign_index)

    fmt.fprintfln(file, "vector_assign_single_%i:", vector_assign_index)
    fmt.fprintfln(file, "  add %s, %s ; add", operand(limit_location), operand(immediate(3 * element_size)))

    fmt.fprintfln(file, "vector_assign_single_loop_%i:", vector_assign_index)
    fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(lhs_address_location), operand(limit_location))
    fmt.fprintfln(file, "  jg vector_assign_single_end_%i ; skip to end", vector_assign_index)

    fmt.fprintfln(file, "  movs%s %s, %s ; copy", precision, operand(lhs_location), operand(lhs_register_location))

    fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(lhs_address_location), operand(limit_location))
    fmt.fprintfln(file, "  jge vector_assign_single_inc_%i ; skip shuffle", vector_assign_index)
    fmt.fprintfln(file, "  shufp%s %s, %s, 0x39 ; shuffle", precision, operand(lhs_register_location), operand(lhs_register_location))

    fmt.fprintfln(file, "vector_assign_single_inc_%i:", vector_assign_index)
    fmt.fprintfln(file, "  add %s, %s ; add", operand(lhs_address_location), operand(immediate(element_size)))

    fmt.fprintfln(file, "  jmp vector_assign_single_loop_%i", vector_assign_index)

    fmt.fprintfln(file, "vector_assign_single_end_%i:", vector_assign_index)
}

generate_assignment_atomic_integer :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, type_node: ^ast_node, register_num: int)
{
    rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, type_node)

    #partial switch node.type
    {
    case .add_assign:
        fmt.fprintfln(file, "  lock xadd %s, %s ; atomic add assign", operand(lhs_location), operand(rhs_register_location))
    case .subtract_assign:
        fmt.fprintfln(file, "  neg %s ; negate", operand(rhs_register_location))
        fmt.fprintfln(file, "  lock xadd %s, %s ; atomic add assign", operand(lhs_location), operand(rhs_register_location))
    case:
        assert(false, "Failed to generate assignment")
    }
}

generate_assignment_signed_integer :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, type_node: ^ast_node, register_num: int)
{
    #partial switch node.type
    {
    case .add_assign:
        rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, type_node)
        fmt.fprintfln(file, "  add %s, %s ; add assign", operand(lhs_location), operand(rhs_register_location))
    case .subtract_assign:
        rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, type_node)
        fmt.fprintfln(file, "  sub %s, %s ; subtract assign", operand(lhs_location), operand(rhs_register_location))
    case .multiply_assign:
        result_location := copy_to_register(file, lhs_location, register_num, type_node)
        rhs_register_location := copy_to_register(file, rhs_location, register_num + 1, type_node)
        fmt.fprintfln(file, "  imul %s, %s ; multiply assign", operand(result_location), operand(rhs_register_location))
        copy(file, result_location, lhs_location, type_node)
        result_location = lhs_location
    case .divide_assign, .modulo_assign:
        // dividend / divisor

        operation_name := "divide assign"
        output_register_name := "ax"
        if node.type == .modulo_assign
        {
            operation_name = "modulo assign"
            output_register_name = "dx"
        }

        rhs_register_location := copy_to_non_immediate(file, rhs_location, register_num + 1, type_node)
        output_register := register(output_register_name, type_node)
        fmt.fprintfln(file, "  mov %s, 0 ; %s: assign zero to dividend high part", operand(register("dx", type_node)), operation_name)
        fmt.fprintfln(file, "  mov %s, %s ; %s: assign lhs to dividend low part", operand(register("ax", type_node)), operand(lhs_location), operation_name)
        fmt.fprintfln(file, "  idiv %s %s ; %s", operation_size(byte_size_of(type_node)), operand(rhs_register_location), operation_name)
        fmt.fprintfln(file, "  mov %s, %s ; %s: assign result", operand(lhs_location), operand(output_register), operation_name)
    case:
        assert(false, "Failed to generate assignment")
    }
}

generate_expression :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, register_num: int = 0) -> location
{
    expression_ctx := copy_gen_context(ctx, true)

    location := generate_expression_1(file, node, &expression_ctx, register_num, contains_allocations(node))

    close_gen_context(file, ctx, &expression_ctx, "expression", true)

    return location
}

generate_expression_1 :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    _, binary_operator := slice.linear_search(binary_operator_node_types, node.type)
    if !binary_operator
    {
        return generate_primary(file, node, ctx, register_num, contains_allocations)
    }

    lhs_node := &node.children[0]
    rhs_node := &node.children[1]

    operand_type_node := get_type(lhs_node)
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
    _, comparison_operator := slice.linear_search(comparison_operator_node_types, node.type)
    if comparison_operator
    {
        result_location := register(register_num, operand_type_node)
        lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node)

        fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(lhs_register_location), operand(rhs_location))

        #partial switch node.type
        {
        case .equal:
            fmt.fprintfln(file, "  sete %s ; equal", operand(result_location))
        case .not_equal:
            fmt.fprintfln(file, "  setne %s ; not equal", operand(result_location))
        case:
            assert(false, "Failed to generate expression")
        }

        return result_location
    }

    result_location := register(register_num, operand_type_node)
    copy(file, lhs_location, result_location, operand_type_node)

    #partial switch node.type
    {
    case .and:
        fmt.fprintfln(file, "  and %s, %s ; and", operand(result_location), operand(rhs_location))
    case .or:
        fmt.fprintfln(file, "  or %s, %s ; or", operand(result_location), operand(rhs_location))
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_expression_float :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, operand_type_node: ^ast_node, result_type_node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    precision := precision(byte_size_of(operand_type_node))

    _, comparison_operator := slice.linear_search(comparison_operator_node_types, node.type)
    if comparison_operator
    {
        lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node)
        result_location := register(register_num, result_type_node)

        fmt.fprintfln(file, "  ucomis%s %s, %s ; compare", precision, operand(lhs_register_location), operand(rhs_location))

        #partial switch node.type
        {
        case .equal:
            fmt.fprintfln(file, "  sete %s ; equal", operand(result_location))
        case .not_equal:
            fmt.fprintfln(file, "  setne %s ; not equal", operand(result_location))
        case .less_than:
            fmt.fprintfln(file, "  setb %s ; less than", operand(result_location))
        case .greater_than:
            fmt.fprintfln(file, "  seta %s ; greater than", operand(result_location))
        case .less_than_or_equal:
            fmt.fprintfln(file, "  setbe %s ; less than or equal", operand(result_location))
        case .greater_than_or_equal:
            fmt.fprintfln(file, "  setae %s ; greater than or equal", operand(result_location))
        case:
            assert(false, "Failed to generate expression")
        }

        return result_location
    }

    result_location := copy_to_register(file, lhs_location, register_num, result_type_node)

    #partial switch node.type
    {
    case .add:
        fmt.fprintfln(file, "  adds%s %s, %s ; add", precision, operand(result_location), operand(rhs_location))
    case .subtract:
        fmt.fprintfln(file, "  subs%s %s, %s ; subtract", precision, operand(result_location), operand(rhs_location))
    case .multiply:
        fmt.fprintfln(file, "  muls%s %s, %s ; multiply", precision, operand(result_location), operand(rhs_location))
    case .divide:
        fmt.fprintfln(file, "  divs%s %s, %s ; divide", precision, operand(result_location), operand(rhs_location))
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_expression_atomic_integer :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, operand_type_node: ^ast_node, result_type_node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    result_location := register(register_num, result_type_node)
    lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node)

    fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(lhs_register_location), operand(rhs_location))

    #partial switch node.type
    {
    case .equal:
        fmt.fprintfln(file, "  sete %s ; equal", operand(result_location))
    case .not_equal:
        fmt.fprintfln(file, "  setne %s ; not equal", operand(result_location))
    case .less_than:
        fmt.fprintfln(file, "  setl %s ; less than", operand(result_location))
    case .greater_than:
        fmt.fprintfln(file, "  setg %s ; greater than", operand(result_location))
    case .less_than_or_equal:
        fmt.fprintfln(file, "  setle %s ; less than or equal", operand(result_location))
    case .greater_than_or_equal:
        fmt.fprintfln(file, "  setge %s ; greater than or equal", operand(result_location))
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_expression_signed_integer :: proc(file: os.Handle, node: ^ast_node, lhs_location: location, rhs_location: location, operand_type_node: ^ast_node, result_type_node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    result_location := register(register_num, result_type_node)

    _, comparison_operator := slice.linear_search(comparison_operator_node_types, node.type)
    if comparison_operator
    {
        lhs_register_location := copy_to_register(file, lhs_location, register_num, operand_type_node)

        fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(lhs_register_location), operand(rhs_location))

        #partial switch node.type
        {
        case .equal:
            fmt.fprintfln(file, "  sete %s ; equal", operand(result_location))
        case .not_equal:
            fmt.fprintfln(file, "  setne %s ; not equal", operand(result_location))
        case .less_than:
            fmt.fprintfln(file, "  setl %s ; less than", operand(result_location))
        case .greater_than:
            fmt.fprintfln(file, "  setg %s ; greater than", operand(result_location))
        case .less_than_or_equal:
            fmt.fprintfln(file, "  setle %s ; less than or equal", operand(result_location))
        case .greater_than_or_equal:
            fmt.fprintfln(file, "  setge %s ; greater than or equal", operand(result_location))
        case:
            assert(false, "Failed to generate expression")
        }

        return result_location
    }

    #partial switch node.type
    {
    case .add:
        result_location = copy_to_register(file, lhs_location, register_num, result_type_node)
        fmt.fprintfln(file, "  add %s, %s ; add", operand(result_location), operand(rhs_location))
    case .subtract:
        result_location = copy_to_register(file, lhs_location, register_num, result_type_node)
        fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(result_location), operand(rhs_location))
    case .multiply:
        result_location = copy_to_register(file, lhs_location, register_num, result_type_node)
        fmt.fprintfln(file, "  imul %s, %s ; multiply", operand(result_location), operand(rhs_location))
    case .divide, .modulo:
        // dividend / divisor

        operation_name := "divide"
        output_register_name := "ax"
        if node.type == .modulo
        {
            operation_name = "modulo"
            output_register_name = "dx"
        }

        rhs_register_location := copy_to_non_immediate(file, rhs_location, register_num + 1, result_type_node)
        output_register := register(output_register_name, result_type_node)
        fmt.fprintfln(file, "  mov %s, 0 ; %s: assign zero to dividend high part", operand(register("dx", result_type_node)), operation_name)
        fmt.fprintfln(file, "  mov %s, %s ; %s: assign lhs to dividend low part", operand(register("ax", result_type_node)), operand(lhs_location), operation_name)
        fmt.fprintfln(file, "  idiv %s %s ; %s", operation_size(byte_size_of(result_type_node)), operand(rhs_register_location), operation_name)
        fmt.fprintfln(file, "  mov %s, %s ; %s: assign result", operand(result_location), operand(output_register), operation_name)
    case:
        assert(false, "Failed to generate expression")
    }

    return result_location
}

generate_primary :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, register_num: int, contains_allocations: bool) -> location
{
    child_location: location
    if node.type != .compound_literal && len(node.children) > 0 && !is_type(&node.children[0])
    {
        child_location = generate_primary(file, &node.children[0], ctx, register_num, contains_allocations)
    }

    type_node := get_type(node)

    #partial switch node.type
    {
    case .reference:
        location := register(register_num, type_node)
        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(location), operand(child_location))
        return location
    case .negate:
        location := copy_to_register(file, child_location, register_num, type_node)

        _, float_type := slice.linear_search(float_types, get_type_value(type_node))
        if float_type
        {
            sign_mask_name := strings.concatenate({ get_type_value(type_node), "_sign_mask" })
            sign_mask := copy_to_register(file, memory(sign_mask_name, 0), register_num + 1, type_node)
            fmt.fprintfln(file, "  xorp%s %s, %s ; negate", precision(byte_size_of(type_node)), operand(location), operand(sign_mask))
        }
        else
        {
            fmt.fprintfln(file, "  neg %s ; negate", operand(location))
        }

        return location
    case .not:
        location := copy_to_non_immediate(file, child_location, register_num, type_node)
        fmt.fprintfln(file, "  xor byte %s, 1 ; not", operand(location))
        return location
    case .dereference:
        location := copy_to_register(file, child_location, register_num, &unknown_reference_type_node, "dereference")
        return memory(operand(location), 0)
    case .index:
        child_type_node := get_type(&node.children[0])

        child_length_location := get_length_location(child_type_node, child_location)

        start_expression_node := &node.children[1]
        start_expression_location := immediate(0)
        if start_expression_node.type != .nil_
        {
            start_expression_location = generate_expression(file, start_expression_node, ctx, register_num + 1)
        }

        start_expression_type_node := get_type(start_expression_node)
        start_expression_location = copy_to_register(file, start_expression_location, register_num + 1, start_expression_type_node)
        start_expression_location = convert(file, start_expression_location, register_num + 1, start_expression_type_node, &index_type_node)

        if start_expression_node.type != .nil_ && type_node.directive != "#boundless"
        {
            fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(start_expression_location), operand(child_length_location))
            fmt.fprintln(file, "  jge panic_out_of_bounds ; panic!")
            fmt.fprintfln(file, "  cmp %s, 0 ; compare", operand(start_expression_location))
            fmt.fprintln(file, "  jl panic_out_of_bounds ; panic!")
        }

        if type_node.value != "[slice]" && node.children[1].type == .number
        {
            data_location := child_location
            if child_type_node.value == "[slice]"
            {
                data_location = copy_to_register(file, data_location, register_num, &unknown_reference_type_node, "dereference")
                data_location = memory(operand(data_location), 0)
            }

            data_location.offset += strconv.atoi(start_expression_node.value) * byte_size_of(type_node)
            return data_location
        }

        address_location := get_raw_location(file, child_type_node, child_location, register_num)
        address_location = copy_to_register(file, address_location, register_num, &unknown_reference_type_node)
        offset_location := register(register_num + 2, &unknown_reference_type_node)
        element_type_node := child_type_node.value == "[array]" || child_type_node.value == "[slice]" ? &child_type_node.children[0] : child_type_node

        fmt.fprintfln(file, "  mov %s, %s ; copy", operand(offset_location), operand(start_expression_location))
        fmt.fprintfln(file, "  imul %s, %s ; multiply by element size", operand(offset_location), operand(immediate(byte_size_of(element_type_node))))
        fmt.fprintfln(file, "  add %s, %s ; offset", operand(address_location), operand(offset_location))

        if type_node.value == "[slice]"
        {
            allocate(file, byte_size_of(type_node), ctx)
            slice_address_location := memory("rsp", 0)
            slice_length_location := memory("rsp", address_size)

            copy(file, address_location, slice_address_location, &unknown_reference_type_node)

            end_expression_node := &node.children[2]
            end_expression_location := child_length_location
            if end_expression_node.type != .nil_
            {
                end_expression_location = generate_expression(file, end_expression_node, ctx, register_num + 2)
            }

            end_expression_type_node := get_type(end_expression_node)
            end_expression_location = copy_to_register(file, end_expression_location, register_num + 2, end_expression_type_node)
            end_expression_location = convert(file, end_expression_location, register_num + 2, end_expression_type_node, &index_type_node)

            if end_expression_node.type != .nil_ && type_node.directive != "#boundless"
            {
                fmt.fprintfln(file, "  cmp %s, %s ; compare", operand(end_expression_location), operand(child_length_location))
                fmt.fprintln(file, "  jg panic_out_of_bounds ; panic!")
                fmt.fprintfln(file, "  cmp %s, 0 ; compare", operand(end_expression_location))
                fmt.fprintln(file, "  jl panic_out_of_bounds ; panic!")
            }

            fmt.fprintfln(file, "  mov %s, %s ; copy", operand(slice_length_location), operand(end_expression_location))
            fmt.fprintfln(file, "  sub %s, %s ; subtract", operand(slice_length_location), operand(start_expression_location))
            fmt.fprintfln(file, "  cmp qword %s, 0 ; compare", operand(slice_length_location))
            fmt.fprintln(file, "  jl panic_negative_slice_length ; panic!")

            return copy_stack_address(file, 0, register_num)
        }
        else
        {
            return memory(operand(address_location), 0)
        }
    case .call:
        return generate_call(file, node, ctx, register_num, child_location, false)
    case .identifier:
        if type_node.allocator == "static"
        {
            return immediate(node.value)
        }

        if is_member(node)
        {
            child_type_node := get_type(&node.children[0])
            switch child_type_node.value
            {
            case "[struct]":
                location := child_location

                for &member_node in child_type_node.children
                {
                    if member_node.value == node.value
                    {
                        break
                    }

                    location.offset += byte_size_of(get_type(&member_node))
                }

                return location
            case "[array]", "[slice]":
                if node.value == "raw"
                {
                    return get_raw_location(file, child_type_node, child_location, register_num)
                }
                else if node.value == "length"
                {
                    return get_length_location(child_type_node, child_location)
                }
            case:
                assert(false, "Failed to generate primary")
            }
        }

        variable_position := ctx.stack_size - ctx.stack_variable_offsets[node.value]
        if contains_allocations
        {
            return copy_stack_address(file, variable_position, register_num)
        }
        else
        {
            return memory("rsp", variable_position)
        }
    case .string_:
        if type_node.value == "[slice]" && type_node.children[0].value == "i8"
        {
            return memory(get_data_section_name(&ctx.data_section_strings, "string_", node.value), 0)
        }
        else if type_node.value == "cstring"
        {
            return immediate(get_data_section_name(&ctx.data_section_cstrings, "cstring_", node.value))
        }

        assert(false, "Failed to generate primary")
        return {}
    case .number:
        if type_node.value == "f32"
        {
            return memory(get_data_section_name(&ctx.data_section_f32s, "f32_", node.value), 0)
        }
        else if type_node.value == "f64"
        {
            return memory(get_data_section_name(&ctx.data_section_f64s, "f64_", node.value), 0)
        }

        return immediate(node.value)
    case .boolean:
        return immediate(node.value == "true" ? 1 : 0)
    case .compound_literal:
        allocate(file, byte_size_of(type_node), ctx)

        if type_node.value == "[struct]"
        {
            member_location := memory("rsp", 0)
            for &member_node in type_node.children
            {
                member_type_node := get_type(&member_node)

                found_assignment := false
                for child_node in node.children
                {
                    child_lhs_node := &child_node.children[0]
                    child_rhs_node := &child_node.children[2]

                    if child_lhs_node.value == member_node.value
                    {
                        expression_location := generate_expression(file, child_rhs_node, ctx, register_num)
                        copy(file, expression_location, member_location, member_type_node)
                        found_assignment = true
                        break
                    }
                }

                if !found_assignment
                {
                    nilify(file, member_location, member_type_node)
                }

                member_location.offset += byte_size_of(get_type(&member_node))
            }
        }
        else if type_node.value == "[slice]"
        {
            member_names: []string = { "raw", "length" }
            for member_name in member_names
            {
                member_type_node := unknown_reference_type_node
                member_location := memory("rsp", 0)
                if member_name == "length"
                {
                    member_type_node = { type = .type, value = "i64" }
                    member_location.offset += address_size
                }

                found_assignment := false
                for child_node in node.children
                {
                    child_lhs_node := &child_node.children[0]
                    child_rhs_node := &child_node.children[2]

                    if child_lhs_node.value == member_name
                    {
                        expression_location := generate_expression(file, child_rhs_node, ctx, register_num)
                        copy(file, expression_location, member_location, &member_type_node)
                        found_assignment = true
                        break
                    }
                }

                if !found_assignment
                {
                    nilify(file, member_location, &member_type_node)
                }
            }
        }
        else
        {
            assert(false, "Failed to generate primary")
        }

        return copy_stack_address(file, 0, register_num)
    case .nil_:
        return immediate(0)
    case:
        return generate_expression_1(file, node, ctx, register_num, contains_allocations)
    }
}

generate_call :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, register_num: int, child_location: location, deallocate_return: bool) -> location
{
    procedure_node := &node.children[0]
    if is_type(procedure_node)
    {
        return generate_conversion_call(file, node, ctx, register_num)
    }

    procedure_type_node := get_type(procedure_node)

    params_type_node := procedure_type_node.children[0]
    return_type_node := len(procedure_type_node.children) == 2 ? &procedure_type_node.children[1] : nil

    call_stack_size := 0
    return_only_call_stack_size := 0
    if procedure_type_node.directive != "#extern"
    {
        for &param_node in params_type_node.children
        {
            call_stack_size += byte_size_of(get_type(&param_node))
        }
        if return_type_node != nil
        {
            call_stack_size += byte_size_of(return_type_node)
            return_only_call_stack_size += byte_size_of(return_type_node)
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

    if procedure_type_node.directive == "#extern"
    {
        for &param_node_from_type, param_index in params_type_node.children
        {
            param_node := &node.children[param_index + 1]
            param_type_node := get_type(&param_node_from_type)

            param_registers_named := procedure_node.value == "syscall" ? syscall_param_registers_named : extern_param_registers_named
            param_registers_numbered := procedure_node.value == "syscall" ? syscall_param_registers_numbered : extern_param_registers_numbered

            expression_location := generate_expression(file, param_node, ctx, register_num)

            param_location: location
            if param_index < len(param_registers_named)
            {
                param_location = register(param_registers_named[param_index], param_type_node)
            }
            else if param_index < len(param_registers_named) + len(param_registers_numbered)
            {
                param_location = register(param_registers_numbered[param_index - len(param_registers_named)], param_type_node)
            }
            else
            {
                assert(false, "Pass by stack not yet supported when calling c")
            }

            copy(file, expression_location, param_location, param_type_node)
        }
    }
    else
    {
        offset := call_stack_size - return_only_call_stack_size
        for &param_node_from_type, param_index in params_type_node.children
        {
            param_node := &node.children[param_index + 1]
            param_type_node := get_type(&param_node_from_type)

            offset -= byte_size_of(param_type_node)

            expression_location := generate_expression(file, param_node, ctx, register_num)
            copy(file, expression_location, memory("rsp", offset), param_type_node)
        }

        if !deallocate_return
        {
            call_stack_size -= return_only_call_stack_size
        }
    }

    if procedure_node.value == "syscall"
    {
        fmt.fprintln(file, "  syscall ; call kernal")
    }
    else
    {
        fmt.fprintfln(file, "  call %s ; call procedure (%s)", operand(child_location), procedure_node.value)
    }

    deallocate(file, call_stack_size, ctx)

    if return_type_node == nil
    {
        return {}
    }

    if procedure_type_node.directive == "#extern"
    {
        return register("ax", return_type_node)
    }
    else
    {
        return copy_stack_address(file, 0, register_num)
    }
}

generate_conversion_call :: proc(file: os.Handle, node: ^ast_node, ctx: ^gen_context, register_num: int) -> location
{
    procedure_node := &node.children[0]
    procedure_type_node := get_type(procedure_node)

    param_type_node := &procedure_type_node.children[0].children[0].children[0]
    return_type_node := &procedure_type_node.children[1]

    param_location := generate_expression(file, &node.children[1], ctx, register_num)

    return convert(file, param_location, register_num, param_type_node, return_type_node)
}

convert :: proc(file: os.Handle, src: location, register_num: int, src_type_node: ^ast_node, dest_type_node: ^ast_node) -> location
{
    if dest_type_node.value == src_type_node.value
    {
        return src
    }

    dest_location := register(register_num, dest_type_node)

    _, src_float_type := slice.linear_search(float_types, src_type_node.value)
    _, src_atomic_integer_type := slice.linear_search(atomic_integer_types, src_type_node.value)
    _, src_signed_integer_type := slice.linear_search(signed_integer_types, src_type_node.value)

    _, dest_float_type := slice.linear_search(float_types, dest_type_node.value)
    _, dest_atomic_integer_type := slice.linear_search(atomic_integer_types, dest_type_node.value)
    _, dest_signed_integer_type := slice.linear_search(signed_integer_types, dest_type_node.value)

    src_size := byte_size_of(src_type_node)
    dest_size := byte_size_of(dest_type_node)

    if src_atomic_integer_type || src_signed_integer_type
    {
        if dest_atomic_integer_type || dest_signed_integer_type
        {
            if dest_size > src_size
            {
                fmt.fprintfln(file, "  movsx %s, %s %s ; convert", operand(dest_location), operation_size(src_size), operand(src))
            }
            else if src.type != .register
            {
                dest_location = src
            }
        }
        else if dest_float_type
        {
            fmt.fprintfln(file, "  cvtsi2s%s %s, %s ; convert", precision(dest_size), operand(dest_location), operand(src))
        }
    }
    else if src_float_type
    {
        if dest_atomic_integer_type || dest_signed_integer_type
        {
            fmt.fprintfln(file, "  cvtts%s2si %s, %s ; convert", precision(src_size), operand(dest_location), operand(src))
        }
        else if dest_float_type
        {
            fmt.fprintfln(file, "  cvts%s2s%s %s, %s ; convert", precision(src_size), precision(dest_size), operand(dest_location), operand(src))
        }
    }

    return dest_location
}

copy_to_non_immediate :: proc(file: os.Handle, src: location, number: int, type_node: ^ast_node, comment: string = "") -> location
{
    if src.type != .immediate
    {
        return src
    }

    final_comment := "copy to non-immediate"
    if comment != ""
    {
        final_comment = comment
    }

    register_dest := register(number, type_node)
    copy(file, src, register_dest, type_node, final_comment)
    return register_dest
}

// TODO review, could change to copy_to_non_immediate in some places
copy_to_register :: proc(file: os.Handle, src: location, number: int, type_node: ^ast_node, comment: string = "") -> location
{
    if src.type == .register
    {
        return src
    }

    final_comment := "copy to register"
    if comment != ""
    {
        final_comment = comment
    }

    register_dest := register(number, type_node)
    copy(file, src, register_dest, type_node, final_comment)
    return register_dest
}

copy_stack_address :: proc(file: os.Handle, offset: int, register_num: int) -> location
{
    dest := register(register_num, &unknown_reference_type_node)
    copy(file, register("sp", &unknown_reference_type_node), dest, &unknown_reference_type_node, "copy stack address")
    return memory(operand(dest), offset)
}

copy :: proc(file: os.Handle, src: location, dest: location, type_node: ^ast_node, comment: string = "")
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
    size := byte_size_of(type_node)

    if src.type == .register || dest.type == .register
    {
        if float_type
        {
            fmt.fprintfln(file, "  movs%s %s, %s ; %s", precision(size), operand(dest), operand(src), final_comment)
        }
        else
        {
            fmt.fprintfln(file, "  mov %s, %s ; %s", operand(dest), operand(src), final_comment)
        }
    }
    else if src.type == .immediate
    {
        assert(!float_type, "Cannot copy float from immediate")

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

copy_gen_context := proc(ctx: ^gen_context, inline := false) -> gen_context
{
    ctx_copy: gen_context
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

        ctx_copy.label_index = ctx.label_index
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
        parent_ctx.label_index = ctx.label_index
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
    if node.type == .compound_literal
    {
        return true
    }

    if node.type == .index && get_type(node).value != "[slice]"
    {
        return true
    }

    if node.type == .call && get_type(&node.children[0]).directive != "#extern"
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

register_named :: proc(name: string, type_node: ^ast_node) -> location
{
    _, float_type := slice.linear_search(float_types, type_node.value)
    if float_type
    {
        assert(false, "Unsupported data type")
        return {}
    }

    switch byte_size_of(type_node)
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

register_numbered :: proc(number: int, type_node: ^ast_node) -> location
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

    switch byte_size_of(type_node)
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

byte_size_of :: proc(type_node: ^ast_node) -> int
{
    if type_node.type == .reference
    {
        return address_size
    }

    switch type_node.value
    {
    case "atomic_i8", "bool", "i8": return 1
    case "atomic_i16", "i16": return 2
    case "atomic_i32", "f32", "i32": return 4
    case "atomic_i64", "f64", "i64": return 8
    case "[procedure]", "cstring": return address_size
    case "[slice]": return address_size + 8 /* i64 */
    case "[array]":
        element_size := byte_size_of(&type_node.children[0])
        length := strconv.atoi(type_node.children[1].value)
        return element_size * length
    case "[struct]":
        size := 0
        for &member_node in type_node.children
        {
            size += byte_size_of(get_type(&member_node))
        }

        return size
    case "cint": return 4 // TODO platform dependant
    }

    assert(false, "Unsupported byte size")
    return 0
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

get_raw_location :: proc(file: os.Handle, container_type_node: ^ast_node, container_location: location, register_num: int) -> location
{
    switch container_type_node.value
    {
    case "[array]":
        location := register(register_num, &unknown_reference_type_node)
        fmt.fprintfln(file, "  lea %s, %s ; reference", operand(location), operand(container_location))
        return location
    case "[slice]":
        return container_location
    }

    assert(false, "Unsupported raw location")
    return {}
}

get_length_location :: proc(container_type_node: ^ast_node, container_location: location) -> location
{
    switch container_type_node.value
    {
    case "[array]":
        return immediate(container_type_node.children[1].value)
    case "[slice]":
        length_location := container_location
        length_location.offset += address_size
        return length_location
    }

    assert(false, "Unsupported length location")
    return immediate(1)
}

get_data_section_name :: proc(data_section_values: ^[dynamic]string, prefix: string, value: string) -> string
{
    index := len(data_section_values)
    for existing_value, existing_index in data_section_values
    {
        if existing_value == value
        {
            index = existing_index
            break
        }
    }

    if index == len(data_section_values)
    {
        append(data_section_values, value)
    }

    buf: [8]byte
    return strings.concatenate({ prefix, strconv.itoa(buf[:], index) })
}

nilify :: proc(file: os.Handle, location: location, type_node: ^ast_node)
{
    assert(location.type == .memory, "Cannot nilify a non-memory location")

    fmt.fprintfln(file, "  lea rdi, %s ; nil: dest", operand(location))
    fmt.fprintfln(file, "  mov rcx, %i ; nil: count", byte_size_of(type_node))
    fmt.fprintln(file, "  mov rax, 0 ; nil: value")
    fmt.fprintln(file, "  rep stosb ; nil")
}
