package type_checking

import "../program"
import fmt "core:fmt"

type_check_program :: proc(the_program: ^program.program, path: []string, code: string) -> bool
{
  program.load_module(the_program, path, code) or_return

  type_checking_ctx: type_checking_context =
  {
    program = the_program,
    path = path
  }
  type_check_module(&type_checking_ctx) or_return

  for len(the_program.queue) > 0
  {
    proc_path := pop(&the_program.queue)
    qualified_name := program.get_qualified_name(proc_path[:])
    procedure := &the_program.procedures[qualified_name]
    if procedure.type_checked
    {
      continue
    }

    procedure_ctx: type_checking_context =
    {
      program = the_program,
      path = proc_path[:]
    }

    type_check_procedure(procedure.statements[0], &procedure_ctx) or_return

    procedure.type_checked = true
    procedure.identifiers = procedure_ctx.identifiers
  }

  import_path: [dynamic]string
  defer delete(import_path)

  type_check_cyclic_imports(the_program, path, &import_path) or_return

  return true
}
