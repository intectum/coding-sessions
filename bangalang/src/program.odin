package main

import "core:fmt"

procedure :: struct
{
    statements: [dynamic]ast_node,
    references: [dynamic]string
}

module :: struct
{
    imports: map[string]string,
    identifiers: map[string]ast_node
}

program :: struct
{
    modules: map[string]module,
    procedures: map[string]procedure
}

import_module :: proc(program: ^program, name: string, src: string) -> bool
{
    if name in program.modules
    {
        return true
    }

    tokens: [dynamic]token
    tokenize(name, src, &tokens) or_return

    stream := token_stream { tokens = tokens[:] }
    nodes, parse_ok := parse_module(&stream)
    if !parse_ok
    {
        next_token := peek_token(&stream)
        file_error("Failed to parse", next_token.file_info)
        fmt.println(stream.error)
        return false
    }

    program.modules[name] = {}
    program.procedures[name] = { statements = nodes }

    ctx: type_checking_context = { program = program, module_name = name, procedure_name = name }
    type_check_module(&ctx) or_return

    return true
}
