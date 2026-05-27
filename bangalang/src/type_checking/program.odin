package type_checking

import "core:fmt"

import "../ast"
import "../loading"

type_check_program :: proc(program: ^ast.scope, path: []string, code: string) -> bool
{
  loading.load_module(program, path, code) or_return

  module := ast.get_scope(program, path)
  program_ctx: type_checking_context =
  {
    root = program,
    scope = module
  }
  type_check_statements(&program_ctx, module.statements[:]) or_return

  for len(queue) > 0
  {
    procedure_path := pop(&queue)
    procedure := ast.get_scope(program, procedure_path[:])

    if procedure.type_checked
    {
      continue
    }

    procedure_ctx: type_checking_context =
    {
      root = program,
      scope = procedure
    }

    type_check_procedure(&procedure_ctx, procedure.statements[0]) or_return

    procedure.type_checked = true
  }

  import_path: [dynamic]string
  defer delete(import_path)

  type_check_cyclic_imports(program, path, &import_path) or_return

  return true
}
