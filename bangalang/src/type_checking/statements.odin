package type_checking

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

import "../ast"
import "../program"
import "../src"

lib_locations: []string =
{
  strings.concatenate({ filepath.dir(filepath.dir(os.args[0])), "/stdlib" }),
  "lib"
}

type_check_statements :: proc(ctx: ^type_checking_context, statements: []ast.node) -> bool
{
  for &statement in statements
  {
    resolve_types(&statement, ctx) or_return

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
      module_name := rhs_node.children[1].value
      module_name = module_name[1:len(module_name) - 1]
      lib_name := len(rhs_node.children) == 3 ? rhs_node.children[2].value : strings.concatenate({ "\"", ctx.path[0], "\"" })
      lib_name = lib_name[1:len(lib_name) - 1]

      lib_path := "."
      if lib_name != "[main]"
      {
        for lib_location in lib_locations
        {
          the_lib_path := strings.concatenate({ lib_location, "/", lib_name })
          if os.is_dir(the_lib_path)
          {
            lib_path = the_lib_path
            break
          }
        }

        if lib_path == "."
        {
          src.print_position_message(lhs_node.src_position, "Library '%s' not found", lib_name)
          return false
        }
      }

      path: [2]string = { lib_name, module_name }
      qualified_module_name := program.get_qualified_module_name(ctx.path)
      qualified_imported_module_name := program.get_qualified_module_name(path[:])


      if qualified_imported_module_name in ctx.program.modules
      {
        module := &ctx.program.modules[qualified_module_name]
        module.imports[reference] = path

        continue
      }

      file_path := strings.concatenate({ lib_path, "/", module_name, ".bang" })
      module_data, read_ok := os.read_entire_file(file_path)
      if !read_ok
      {
        src.print_position_message(lhs_node.src_position, "Failed to read module file '%s'", module_name)
        return false
      }

      program.load_module(ctx.program, path[:], string(module_data)) or_return

      imported_module_ctx: type_checking_context =
      {
        program = ctx.program,
        path = path[:]
      }
      type_check_module(&imported_module_ctx) or_return

      module := &ctx.program.modules[qualified_module_name]
      module.imports[reference] = path
    }
    else if ast.is_static_procedure_statement(&statement)
    {
      lhs_node := &statement.children[0]
      lhs_type_node := ast.get_type(lhs_node)

      ctx.identifiers[lhs_node.value] = lhs_node^

      procedure: program.procedure
      append(&procedure.statements, statement)

      procedure_path: [dynamic]string
      append(&procedure_path, ..ctx.path)
      append(&procedure_path, lhs_node.value)

      qualified_name := program.get_qualified_name(procedure_path[:])
      ctx.program.procedures[qualified_name] = procedure
      append(&ctx.program.queue, procedure_path)
    }
  }

  failures := false
  for &statement in statements
  {
    if ast.is_type_alias_statement(&statement) || ast.is_static_procedure_statement(&statement)
    {
      continue
    }

    if !type_check_statement(&statement, ctx)
    {
      failures = true
    }
  }

  return !failures
}
