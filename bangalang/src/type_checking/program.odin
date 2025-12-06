package type_checking

import "../ast"

type_check_program :: proc(ctx: ^type_checking_context) -> bool
{
  type_check_module(ctx) or_return

  for len(the_program.queue) > 0
  {
    proc_path := pop(&the_program.queue)
    procedure := ast.get_scope(ctx.root, proc_path[:])
    if procedure.type_checked
    {
      continue
    }

    procedure_ctx: type_checking_context =
    {
      root = ctx.root,
      current = procedure,
      path = proc_path[:]
    }

    type_check_procedure(&procedure_ctx, procedure.statements[0]) or_return

    procedure.type_checked = true
    procedure.identifiers = procedure_ctx.identifiers
  }

  import_path: [dynamic]string
  defer delete(import_path)

  type_check_cyclic_imports(ctx, &import_path) or_return

  return true
}
