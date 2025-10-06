package type_checking

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "../ast"
import "../program"

type_check_module :: proc(ctx: ^type_checking_context) -> bool
{
  qualified_main_name := program.get_qualified_name(ctx.module_name, ctx.procedure_name)
  main_procedure := &ctx.program.procedures[qualified_main_name]

  type_check_statements(ctx, main_procedure.statements[:])

  module := &ctx.program.modules[ctx.module_name]
  module.identifiers = ctx.identifiers

  return true
}
