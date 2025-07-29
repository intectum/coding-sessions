package main

import "core:fmt"

module :: struct
{
    nodes: [dynamic]ast_node,
    ctx: type_checking_context
}

imported_modules: map[string]module

import_module :: proc(name: string, src: string) -> bool
{
    if name in imported_modules
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

    module: module = { nodes = nodes }
    type_check_module(&module) or_return

    imported_modules[name] = module

    return true
}
