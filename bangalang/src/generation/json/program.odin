package json

import "core:fmt"
import "core:slice"

import "../../ast"
import ".."

generate_program :: proc(ctx: ^generation.gen_context)
{
  fmt.sbprintln(&ctx.output, "{")
  fmt.sbprintln(&ctx.output, "  \"type\": \"loading\",")
  fmt.sbprintln(&ctx.output, "  \"children\":")
  fmt.sbprintln(&ctx.output, "  [")

  generated_import_names: [dynamic]string
  generate_main_statements(ctx, ctx.scope, &generated_import_names, false)

  fmt.sbprintln(&ctx.output, "")
  fmt.sbprintln(&ctx.output, "  ]")
  fmt.sbprintln(&ctx.output, "}")
}

generate_main_statements :: proc(ctx: ^generation.gen_context, module: ^ast.scope, generated_import_names: ^[dynamic]string, generated_statement: bool)
{
  generated_statement := generated_statement

  module_name := ast.get_scope_name(module.path)
  _, found_generated_module := slice.linear_search(generated_import_names[:], module_name)
  if found_generated_module
  {
    return
  }

  append(generated_import_names, module_name)

  for reference in module.references
  {
    if len(reference.path) != 2 do continue

    imported_module := ast.get_scope(ctx.root, reference.path[:])
    generate_main_statements(ctx, imported_module, generated_import_names, generated_statement)
    generated_statement = true
  }

  for statement in module.statements
  {
    if generated_statement
    {
      fmt.sbprintln(&ctx.output, ",")
    }

    ast.print_node(&ctx.output, statement, 2)
    generated_statement = true
  }
}
