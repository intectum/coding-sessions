package loading

import "core:fmt"

import "../ast"
import "../parsing"
import "../tokenization"
import "../tokens"

load_module :: proc(root: ^ast.scope, path: []string, code: string) -> bool
{
    if ast.get_module(root, path) != nil
    {
        return true
    }

    tokenization_result := tokenization.tokenize(ast.to_path_name(path), code) or_return

    stream := tokens.stream { tokens = tokenization_result[:] }
    statements, parse_ok := parsing.parse_module(&stream)
    if !parse_ok
    {
        fmt.println(stream.error)
        return false
    }

    if !(path[0] in root.children)
    {
        root.children[path[0]] = {}
    }

    module := new(ast.scope)
    module^ = { statements = statements }
    root.children[path[0]].children[path[1]] = module

    return true
}
