package type_checking

import "core:fmt"

import "../ast"
import "../loading"

queue: [dynamic][dynamic]string

type_check_queue :: proc(program: ^ast.scope) -> bool
{
  for len(queue) > 0
  {
    proc_path := pop(&queue)
    procedure := ast.get_scope(program, proc_path[:])
    if procedure == nil || procedure.type_checked
    {
      continue
    }

    procedure_ctx: type_checking_context =
    {
      program = program,
      scope = procedure,
      within_kernel = procedure.statements[0].children[0].data_type.type == .kernel_type
    }

    type_check_procedure(&procedure_ctx, procedure.statements[0]) or_return

    procedure.type_checked = true
  }

  return true
}
