package type_checking

import "../program"

type_check_program :: proc(the_program: ^program.program, name: string, code: string) -> bool
{
    program.load_module(the_program, name, code) or_return

    type_checking_ctx: type_checking_context =
    {
        program = the_program,
        module_name = name,
        procedure_name = "[main]"
    }
    type_check_module(&type_checking_ctx) or_return

    import_path: [dynamic]string
    defer delete(import_path)

    type_check_cyclic_imports(the_program, name, &import_path) or_return

    return true
}
