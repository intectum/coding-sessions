package x86_64

import "../../ast"
import ".."

generate_statements :: proc(ctx: ^generation.gen_context, statements: []ast.node)
{
  for &statement in statements
  {
    if ast.is_link_statement(&statement) || ast.is_import_statement(&statement) || ast.is_type_alias_statement(&statement) || ast.is_static_procedure_statement(&statement)
    {
      continue
    }

    generate_statement(ctx, &statement)
  }
}
