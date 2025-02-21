package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:strconv"

stack :: struct
{
    top: int,
    vars: map[string]int
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

    stack: stack

    for node in nodes
    {
        generate_statement(file, node, &stack)
    }

    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  mov rdi, 0 ; arg0: exit_code")
    fmt.fprintln(file, "  syscall ; call kernel")
}

generate_statement :: proc(file: os.Handle, node: ast_node, stack: ^stack)
{
    #partial switch node.type
    {
    case .SCOPE:
        generate_scope(file, node, stack)
    case .DECLARATION_STATEMENT:
        generate_declaration_statement(file, node, stack)
    case .ASSIGNMENT_STATEMENT:
        generate_assignment_statement(file, node, stack)
    case .EXIT_STATEMENT:
        generate_exit_statement(file, node, stack)
    case:
        fmt.println("Failed to generate statement")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }
}

generate_scope :: proc(file: os.Handle, node: ast_node, parent_stack: ^stack)
{
    fmt.fprintln(file, "; scope start")

    scope_stack: stack
    scope_stack.top = parent_stack.top
    for key in parent_stack.vars
    {
        scope_stack.vars[key] = parent_stack.vars[key]
    }

    for child_node in node.children
    {
        generate_statement(file, child_node, &scope_stack)
    }

    scope_stack_size := scope_stack.top - parent_stack.top

    fmt.fprintfln(file, "  add rsp, %i ; clear scope's stack", scope_stack_size)
    fmt.fprintln(file, "; scope end")
}

generate_declaration_statement :: proc(file: os.Handle, node: ast_node, stack: ^stack)
{
    fmt.fprintln(file, "  ; declare")

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    if lhs_node.value in stack.vars
    {
        fmt.println("Failed to generate declaration statement")
        fmt.printfln("Duplicate identifier '%s' at line %i, column %i", lhs_node.value, lhs_node.line_number, lhs_node.column_number)
        os.exit(1)
    }

    fmt.fprintfln(file, "  mov [rsp], %s ; assign value", generate_expression(file, rhs_node, stack))
    stack.vars[lhs_node.value] = stack.top

    fmt.fprintln(file, "  sub rsp, 8 ; allocate space on stack")
    stack.top += 8
}

generate_assignment_statement :: proc(file: os.Handle, node: ast_node, stack: ^stack)
{
    fmt.fprintln(file, "  ; assign")

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    if !(lhs_node.value in stack.vars)
    {
        fmt.println("Failed to generate assignment statement")
        fmt.printfln("Undeclared identifier '%s' at line %i, column %i", lhs_node.value, lhs_node.line_number, lhs_node.column_number)
        os.exit(1)
    }

    var_pointer := stack.vars[lhs_node.value]
    var_offset := stack.top - var_pointer
    fmt.fprintfln(file, "  mov [rsp+%i], %s ; assign value", var_offset, generate_expression(file, rhs_node, stack))
}

generate_exit_statement :: proc(file: os.Handle, node: ast_node, stack: ^stack)
{
    fmt.fprintln(file, "  ; exit")

    param_node := node.children[0]

    fmt.fprintfln(file, "  mov rdi, %s ; arg0: exit_code", generate_expression(file, param_node, stack))
    fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
    fmt.fprintln(file, "  syscall ; call kernel")
}

generate_expression :: proc(file: os.Handle, node: ast_node, stack: ^stack) -> string
{
    if len(node.children) == 0
    {
        fmt.fprintfln(file, "  mov rax, %s ; assign term to rax", generate_term(node, stack))
        return "rax"
    }

    lhs_node := node.children[0]
    rhs_node := node.children[1]

    fmt.fprintfln(file, "  mov rax, %s ; assign lhs to rax", generate_term(lhs_node, stack))

    #partial switch node.type
    {
    case .ADD:
        fmt.fprintfln(file, "  add rax, %s ; add rhs to rax", generate_term(rhs_node, stack))
    case .SUBTRACT:
        fmt.fprintfln(file, "  sub rax, %s ; subtract rhs from rax", generate_term(rhs_node, stack))
    case .MULTIPLY:
        fmt.fprintfln(file, "  imul rax, %s ; multiply rhs by rax", generate_term(rhs_node, stack))
    case .DIVIDE:
        fmt.fprintln(file, "  mov rdx, 0 ; zero out rdx")
        fmt.fprintfln(file, "  mov rbx, %s ; assign rhs to rbx", generate_term(rhs_node, stack))
        fmt.fprintln(file, "  idiv rbx ; divide by rhs")
    case:
        fmt.println("Failed to generate expression")
        fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
        os.exit(1)
    }

    return "rax"
}

generate_term :: proc(node: ast_node, stack: ^stack) -> string
{
    if node.type == .IDENTIFIER
    {
        if !(node.value in stack.vars)
        {
            fmt.println("Failed to generate term")
            fmt.printfln("Undeclared identifier '%s' at line %i, column %i", node.value, node.line_number, node.column_number)
            os.exit(1)
        }

        var_pointer := stack.vars[node.value]
        var_offset := stack.top - var_pointer

        buf: [256]byte

        return strings.concatenate({ "[rsp+", strconv.itoa(buf[:], var_offset), "]" })
    }
    else if node.type == .INTEGER_LITERAL
    {
        return node.value
    }

    fmt.println("Failed to generate term")
    fmt.printfln("Invalid node at line %i, column %i", node.line_number, node.column_number)
    os.exit(1)
}
