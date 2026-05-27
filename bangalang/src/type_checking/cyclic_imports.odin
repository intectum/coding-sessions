package type_checking

import "core:fmt"
import "core:slice"
import "core:strings"

import "../ast"

type_check_cyclic_imports :: proc(root: ^ast.scope, path: []string, import_path: ^[dynamic]string) -> bool
{
    scope_name := ast.get_scope_name(path)
    module := ast.get_scope(root, path)
    append(import_path, scope_name)
    for reference in module.references
    {
        if len(reference.path) != 2 do continue

        imported_scope_name := ast.get_scope_name(reference.path[:])
        _, found_module := slice.linear_search(import_path[:], imported_scope_name)
        if found_module
        {
            fmt.printfln("Cylic import detected: '%s' imported at path %s", imported_scope_name, import_path^)
            return false
        }

        type_check_cyclic_imports(root, reference.path[:], import_path) or_return
    }
    pop(import_path)

    return true
}
