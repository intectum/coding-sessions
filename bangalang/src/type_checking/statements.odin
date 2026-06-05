package type_checking

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"

import "../ast"
import "../loading"
import "../src"

lib_locations: []string =
{
  strings.concatenate({ filepath.dir(filepath.dir(os.args[0])), "/stdlib" }),
  "lib"
}

type_check_statements :: proc(ctx: ^type_checking_context, statements: []^ast.node) -> bool
{
  for statement in statements
  {
    // TODO move to call?
    if ast.is_import_statement(statement)
    {
      module := ast.get_scope(ctx.program, ctx.scope.path[:2])
      lhs_node := statement.children[0]
      reference := lhs_node.value

      rhs_node := statement.children[2]
      module_name := rhs_node.children[1].value
      module_name = module_name[1:len(module_name) - 1]
      lib_name := len(rhs_node.children) == 3 ? rhs_node.children[2].value : strings.concatenate({ "\"", ctx.scope.path[0], "\"" })
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

      path: [dynamic]string
      append(&path, lib_name, module_name)
      imported_module := ast.get_scope(ctx.program, path[:])

      if imported_module != nil
      {
        module.references[reference] = path
        continue
      }

      file_path := strings.concatenate({ lib_path, "/", module_name, ".bang" })
      module_data, read_ok := os.read_entire_file(file_path)
      if !read_ok
      {
        src.print_position_message(lhs_node.src_position, "Failed to read module file '%s'", module_name)
        return false
      }

      loading.load_module(ctx.program, path[:], string(module_data)) or_return

      imported_module_ctx: type_checking_context =
      {
        program = ctx.program,
        scope = ast.get_scope(ctx.program, path[:])
      }
      type_check_statements(&imported_module_ctx, imported_module_ctx.scope.statements[:]) or_return

      module.references[reference] = path
    }
  }

  failures := false
  for statement in statements
  {
    if !type_check_statement(ctx, statement)
    {
      failures = true
    }
  }

  return !failures
}
