package json

import "core:fmt"
import "core:slice"
import "core:strings"

import "../../ast"
import "../../program"
import ".."
import "../glsl"

generate_program :: proc(ctx: ^generation.gen_context)
{
  fmt.sbprintln(&ctx.output, "{")
  fmt.sbprintln(&ctx.output, "  \"type\": \"program\",")
  fmt.sbprintln(&ctx.output, "  \"children\":")
  fmt.sbprintln(&ctx.output, "  [")

  generated_import_names: [dynamic]string
  generate_main_statements(ctx, ctx.path, &generated_import_names, false)

  fmt.sbprintln(&ctx.output, "")
  fmt.sbprintln(&ctx.output, "  ]")
  fmt.sbprintln(&ctx.output, "}")
}

generate_main_statements :: proc(ctx: ^generation.gen_context, path: []string, generated_import_names: ^[dynamic]string, generated_statement: bool)
{
  generated_statement := generated_statement

  qualified_module_name := program.get_qualified_module_name(path)
  _, found_generated_module := slice.linear_search(generated_import_names[:], qualified_module_name)
  if found_generated_module
  {
    return
  }

  append(generated_import_names, qualified_module_name)

  module := &ctx.program.modules[qualified_module_name]
  for import_name in module.imports
  {
    imported_module_path := module.imports[import_name]
    generate_main_statements(ctx, imported_module_path[:], generated_import_names, generated_statement)
    generated_statement = true
  }

  ctx.path = path

  main_procedure := &ctx.program.procedures[program.get_qualified_name(ctx.path)]
  for statement in main_procedure.statements
  {
    if generated_statement
    {
      fmt.sbprintln(&ctx.output, ",")
    }

    ast.print_node(&ctx.output, statement, 2)
    generated_statement = true
  }
}
