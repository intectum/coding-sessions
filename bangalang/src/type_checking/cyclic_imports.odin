package type_checking

import "core:fmt"
import "core:slice"

import "../program"

type_check_cyclic_imports :: proc(program: ^program.program, module_name: string, import_path: ^[dynamic]string) -> bool
{
    module := &program.modules[module_name]
    append(import_path, module_name)
    for import_name in module.imports
    {
        imported_module_name := module.imports[import_name]
        _, found_module_name := slice.linear_search(import_path[:], imported_module_name)
        if found_module_name
        {
            fmt.printfln("Cylic import detected: '%s' imported at path %s", imported_module_name, import_path^)
            return false
        }

        type_check_cyclic_imports(program, imported_module_name, import_path) or_return
    }
    pop(import_path)

    return true
}
