package type_checking

import "core:fmt"
import "core:slice"
import "core:strings"

import "../ast"

type_check_cyclic_imports :: proc(program: ^ast.scope, path: []string, import_path: ^[dynamic]string) -> bool
{
    readable_name := strings.concatenate({ path[0], ":", path[1] })
    module := ast.get_scope(program, path)
    append(import_path, readable_name)
    for import_name,imported_module_path in module.references
    {
        if len(imported_module_path) != 2 do continue

        imported_readable_name := strings.concatenate({ imported_module_path[0], ":", imported_module_path[1] })
        _, found_module := slice.linear_search(import_path[:], imported_readable_name)
        if found_module
        {
            fmt.printfln("Cylic import detected: '%s' imported at path %s", imported_readable_name, import_path^)
            return false
        }

        type_check_cyclic_imports(program, imported_module_path[:], import_path) or_return
    }
    pop(import_path)

    return true
}
