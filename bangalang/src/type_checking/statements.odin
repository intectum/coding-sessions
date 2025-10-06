package type_checking

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "../ast"
import "../program"

type_check_statements :: proc(ctx: ^type_checking_context, statements: []ast.node) -> bool
{
  for &statement in statements
  {
    resolve_types(&statement, ctx)

    if ast.is_type_alias_statement(&statement)
    {
      lhs_node := &statement.children[0]
      rhs_node := &statement.children[2]

      name := lhs_node.value
      lhs_node^ = rhs_node^
      ctx.identifiers[name] = lhs_node^
    }
    else if ast.is_link_statement(&statement)
    {
      link := statement.children[1].value

      _, found_link := slice.linear_search(ctx.program.links[:], link)
      if found_link
      {
        continue
      }

      append(&ctx.program.links, link)
    }
    else if ast.is_import_statement(&statement)
    {
      lhs_node := &statement.children[0]
      reference := lhs_node.value

      rhs_node := &statement.children[2]
      name := rhs_node.children[1].value
      name = name[1:len(name) - 1]
      path := strings.concatenate({ "stdlib/", name, ".bang" })

      if name in ctx.program.modules
      {
        module := &ctx.program.modules[ctx.module_name]
        module.imports[reference] = name

        continue
      }

      code_data, code_ok := os.read_entire_file(path)
      if !code_ok
      {
        fmt.printfln("Failed to read module file '%s' imported by '%s'", name, ctx.module_name)
        return false
      }

      program.load_module(ctx.program, name, string(code_data)) or_return

      imported_module_ctx: type_checking_context =
      {
        program = ctx.program,
        module_name = name,
        procedure_name = "[main]"
      }
      type_check_module(&imported_module_ctx) or_return

      module := &ctx.program.modules[ctx.module_name]
      module.imports[reference] = name
    }
    else if ast.is_static_procedure_statement(&statement)
    {
      lhs_node := &statement.children[0]
      lhs_type_node := ast.get_type(lhs_node)

      ctx.identifiers[lhs_node.value] = lhs_node^

      procedure: program.procedure
      append(&procedure.statements, statement)

      qualified_name := program.get_qualified_name(ctx.module_name, lhs_node.value)
      ctx.program.procedures[qualified_name] = procedure
      append(&ctx.program.queue, program.reference { ctx.module_name, lhs_node.value })
    }
  }

  for &statement in statements
  {
    if ast.is_type_alias_statement(&statement) || ast.is_static_procedure_statement(&statement)
    {
      continue
    }

    type_check_statement(&statement, ctx) or_return
  }

  return true
}
