package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

gen_context :: struct
{
    in_proc: bool,

    stack_top: int,
    stack_vars: map[string]int,

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

    fmt.fprintln(file, "plus_one:")
    fmt.fprintln(file, "  mov r8, [rsp+8] ; assign arg0")
    fmt.fprintln(file, "  inc r8 ; do it!")
    fmt.fprintln(file, "  ret ; return")

    fmt.fprintln(file, "add:")
    fmt.fprintln(file, "  mov r8, [rsp+16] ; assign arg0")
    fmt.fprintln(file, "  add r8, [rsp+8] ; do it!")
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

        scope_ctx.stack_top += 8
        scope_ctx.stack_vars[param_node.value] = scope_ctx.stack_top
    }
    scope_ctx.stack_top += 8

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

    generate_expression(file, expression_node, ctx)
    fmt.fprintln(file, "  test r8, r8 ; test expression")
    fmt.fprintfln(file, "  jz .if_%i_%s ; skip main scope when false/zero", if_index, child_index < len(node.children) ? "else_0" : "end")

    generate_scope(file, scope_node, ctx)

    for child_index + 1 < len(node.children)
    {
        fmt.fprintfln(file, "  jmp .if_%i_end ; skip else scope", if_index)
        fmt.fprintfln(file, ".if_%i_else_%i:", if_index, else_index)
        else_index += 1

        generate_expression(file, node.children[child_index], ctx)
        child_index += 1

        fmt.fprintln(file, "  test r8, r8 ; test expression")

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
        generate_expression(file, expression_node, ctx)
        fmt.fprintln(file, "  test r8, r8 ; test expression")
        fmt.fprintfln(file, "  jz .for_%i_end ; skip for scope when false/zero", for_index)
    }
    else
    {
        fmt.fprintfln(file, ".for_%i:", for_index)

        expression_node := node.children[0]
        generate_expression(file, expression_node, ctx)
        fmt.fprintln(file, "  test r8, r8 ; test expression")
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

    scope_stack_size := scope_ctx.stack_top - parent_ctx.stack_top
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
    rhs_node := node.children[1]

    generate_expression(file, rhs_node, ctx)
    fmt.fprintln(file, "  push r8 ; push to stack")
    ctx.stack_top += 8
    ctx.stack_vars[lhs_node.value] = ctx.stack_top
}

generate_assignment :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; assign")

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    var_pointer := ctx.stack_vars[lhs_node.value]
    var_offset := ctx.stack_top - var_pointer
    generate_expression(file, rhs_node, ctx)
    fmt.fprintfln(file, "  mov [rsp+%i], r8 ; assign value", var_offset)
}

generate_return :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context)
{
    fmt.fprintln(file, "  ; return")

    expression_node := node.children[0]

    generate_expression(file, expression_node, ctx)

    if ctx.in_proc
    {
        fmt.fprintln(file, "  jmp .end ; skip to end")
    }
    else
    {
        fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
        fmt.fprintln(file, "  mov rdi, r8 ; arg0: exit_code")
        fmt.fprintln(file, "  syscall ; call kernel")
    }
}

generate_expression :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int = 8)
{
    if node.type != .ADD && node.type != .SUBTRACT && node.type != .MULTIPLY && node.type != .DIVIDE
    {
        generate_primary(file, node, ctx, register_num)
        return
    }

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    lhs_register_num := register_num / 2 * 2 + 2
    rhs_register_num := lhs_register_num + 1

    generate_expression(file, lhs_node, ctx, lhs_register_num)
    generate_expression(file, rhs_node, ctx, rhs_register_num)

    #partial switch node.type
    {
    case .ADD:
        fmt.fprintfln(file, "  mov r%i, r%i ; add: assign lhs", register_num, lhs_register_num)
        fmt.fprintfln(file, "  add r%i, r%i ; add: do it!", register_num, rhs_register_num)
    case .SUBTRACT:
        fmt.fprintfln(file, "  mov r%i, r%i ; subtract: assign lhs", register_num, lhs_register_num)
        fmt.fprintfln(file, "  sub r%i, r%i ; subtract: do it!", register_num, rhs_register_num)
    case .MULTIPLY:
        fmt.fprintfln(file, "  mov r%i, r%i ; multiply: assign lhs", register_num, lhs_register_num)
        fmt.fprintfln(file, "  imul r%i, r%i ; multiply: do it!", register_num, rhs_register_num)
    case .DIVIDE:
        // dividend / divisor
        fmt.fprintln(file, "  mov rdx, 0 ; divide: assign zero to dividend high part")
        fmt.fprintfln(file, "  mov rax, r%i ; divide: assign lhs to dividend low part", lhs_register_num)
        fmt.fprintfln(file, "  idiv r%i ; divide: do it!", rhs_register_num)
        fmt.fprintfln(file, "  mov r%i, rax ; divide: assign result", register_num)
    case:
        fmt.println("BUG: Failed to generate expression")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }
}

generate_primary :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int)
{
    #partial switch node.type
    {
    case .CALL:
        generate_call(file, node, ctx, register_num)
    case .IDENTIFIER:
        var_pointer := ctx.stack_vars[node.value]
        var_offset := ctx.stack_top - var_pointer
        fmt.fprintfln(file, "  mov r%i, [rsp+%i] ; assign primary", register_num, var_offset)
    case .INTEGER_LITERAL:
        fmt.fprintfln(file, "  mov r%i, %s ; assign primary", register_num, node.value)
    case .NEGATE:
        generate_primary(file, node.children[0], ctx, register_num)
        fmt.fprintfln(file, "  neg r%i ; negate", register_num)
    case:
        generate_expression(file, node, ctx, register_num)
    }
}

generate_call :: proc(file: os.Handle, node: ast_node, ctx: ^gen_context, register_num: int = 8)
{
    child_index := 0
    name_node := node.children[child_index]
    child_index += 1

    for child_index < len(node.children)
    {
        param_node := node.children[child_index]
        child_index += 1

        generate_expression(file, param_node, ctx)
        fmt.fprintln(file, "  push r8 ; push to stack")
    }

    fmt.fprintfln(file, "  call %s ; call procedure", name_node.value)

    param_count := len(node.children) - 1
    fmt.fprintfln(file, "  add rsp, %i ; clear params from stack", param_count * 8)

    fmt.fprintfln(file, "  mov r%i, r8 ; assign return value", register_num)
}

copy_gen_context := proc(ctx: gen_context, inline := false) -> gen_context
{
    ctx_copy: gen_context
    ctx_copy.in_proc = ctx.in_proc
    ctx_copy.stack_top = ctx.stack_top

    if inline
    {
        for key in ctx.stack_vars
        {
            ctx_copy.stack_vars[key] = ctx.stack_vars[key]
        }

        ctx_copy.if_index = ctx.if_index
        ctx_copy.for_index = ctx.for_index
    }

    return ctx_copy
}
