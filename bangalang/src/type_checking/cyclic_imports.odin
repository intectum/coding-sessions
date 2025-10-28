package type_checking

import "core:fmt"
import "core:slice"
import "core:strings"

import "../program"

type_check_cyclic_imports :: proc(the_program: ^program.program, path: []string, import_path: ^[dynamic]string) -> bool
{
    readable_name := strings.concatenate({ path[0], ":", path[1] })
    module := &the_program.modules[program.get_qualified_module_name(path)]
    append(import_path, readable_name)
    for import_name in module.imports
    {
        imported_module_path := module.imports[import_name]
        imported_readable_name := strings.concatenate({ imported_module_path[0], ":", imported_module_path[1] })
        _, found_module := slice.linear_search(import_path[:], imported_readable_name)
        if found_module
        {
            fmt.printfln("Cylic import detected: '%s' imported at path %s", imported_readable_name, import_path^)
            return false
        }

        type_check_cyclic_imports(the_program, imported_module_path[:], import_path) or_return
    }
    pop(import_path)

    return true
}
