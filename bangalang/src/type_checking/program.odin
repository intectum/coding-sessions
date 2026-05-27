package type_checking

import "core:fmt"

import "../ast"
import "../loading"

type_check_program :: proc(program: ^ast.scope, path: []string, code: string) -> bool
{
  loading.load_module(program, path, code) or_return

  type_checking_ctx: type_checking_context =
  {
    program = program,
    path = path
  }
  type_check_module(&type_checking_ctx) or_return

  for len(queue) > 0
  {
    proc_path := pop(&queue)
    procedure := ast.get_scope(program, proc_path[:])
    if procedure.type_checked
    {
      continue
    }

    procedure_ctx: type_checking_context =
    {
      program = program,
      path = proc_path[:]
    }

    type_check_procedure(&procedure_ctx, procedure.statements[0]) or_return

    procedure.type_checked = true
    procedure.identifiers = procedure_ctx.identifiers
  }

  import_path: [dynamic]string
  defer delete(import_path)

  type_check_cyclic_imports(program, path, &import_path) or_return

  return true
}
