package x86_64

import "../../ast"
import "../../type_checking"
import ".."

generate_statements :: proc(ctx: ^generation.gen_context, output: ^output, statements: []^ast.node)
{
  for statement in statements
  {
    if ast.is_link_statement(statement) || ast.is_import_statement(statement) || ast.is_type_alias_statement(statement) || type_checking.is_static_procedure_statement(ctx.root, statement)
    {
      continue
    }

    generate_statement(ctx, output, statement)
  }
}
