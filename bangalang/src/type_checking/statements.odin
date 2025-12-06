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
    resolve_types(ctx, statement) or_return

    if ast.is_type_alias_statement(statement)
    {
      lhs_node := statement.children[0]
      rhs_node := statement.children[2]

      name := lhs_node.value
      lhs_node^ = rhs_node^
      ctx.identifiers[name] = lhs_node
    }
    else if ast.is_link_statement(statement)
    {
      link := statement.children[1].value
      if link in ctx.root.children do continue

      ctx.root.children[link] = {}
    }
    else if ast.is_import_statement(statement)
    {
      lhs_node := statement.children[0]
      reference := lhs_node.value

      rhs_node := statement.children[2]
      module_name := rhs_node.children[1].value
      module_name = module_name[1:len(module_name) - 1]
      lib_name := len(rhs_node.children) == 3 ? rhs_node.children[2].value : strings.concatenate({ "\"", ctx.path[0], "\"" })
      lib_name = lib_name[1:len(lib_name) - 1]

      lib_file_path := "."
      if lib_name != "[main]"
      {
        for lib_location in lib_locations
        {
          the_lib_file_path := strings.concatenate({ lib_location, "/", lib_name })
          if os.is_dir(the_lib_file_path)
          {
            lib_file_path = the_lib_file_path
            break
          }
        }

        if lib_file_path == "."
        {
          src.print_position_message(lhs_node.src_position, "Library '%s' not found", lib_name)
          return false
        }
      }

      if !(lib_name in ctx.root.children) do ctx.root.children[lib_name] = {}

      module_path: [dynamic]string
      append(&module_path, lib_name, module_name)

      if !(module_name in ctx.root.children[lib_name].children)
      {
        file_path := strings.concatenate({ lib_file_path, "/", module_name, ".bang" })
        module_data, read_ok := os.read_entire_file(file_path)
        if !read_ok
        {
          src.print_position_message(lhs_node.src_position, "Failed to read module file '%s'", module_name)
          return false
        }

        loading.load_module(ctx.root, module_path[:], string(module_data)) or_return

        module_ctx: type_checking_context =
        {
          root = ctx.root,
          current = ast.get_module(ctx.root, module_path[:]),
          path = module_path[:]
        }
        type_check_module(&module_ctx) or_return
      }

      ctx.current.references[reference] = module_path
    }
    else if statement.type == .assignment_statement && statement.children[0].data_type != nil && statement.children[0].data_type.value == "[procedure]"
    {
      lhs_node := statement.children[0]
      ctx.out_of_order_identifiers[lhs_node.value] = lhs_node
    }
  }

  failures := false
  for statement in statements
  {
    if ast.is_type_alias_statement(statement) do continue

    if !type_check_statement(ctx, statement)
    {
      failures = true
    }
  }

  return !failures
}
