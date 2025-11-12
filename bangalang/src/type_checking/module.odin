package type_checking

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "../ast"
import "../program"

type_check_module :: proc(ctx: ^type_checking_context) -> bool
{
  qualified_main_name := program.get_qualified_name(ctx.path[:])
  main_procedure := &ctx.program.procedures[qualified_main_name]

  type_check_statements(ctx, main_procedure.statements[:]) or_return

  module := &ctx.program.modules[program.get_qualified_module_name(ctx.path)]
  for key, value in ctx.identifiers do module.identifiers[key] = value

  return true
}
