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
    if !tokenize(name, src, &tokens)
    {
        fmt.printfln("Failed to tokenize module %s", name)
        return false
    }

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
    if !type_check_module(&module)
    {
        fmt.printfln("Failed to type check module %s", name)
        return false
    }

    imported_modules[name] = module

    return true
}
