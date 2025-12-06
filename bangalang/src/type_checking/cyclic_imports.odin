package type_checking

import "core:fmt"
import "core:slice"
import "core:strings"

import "../ast"

type_check_cyclic_imports :: proc(ctx: ^type_checking_context, import_path: ^[dynamic]string) -> bool
{
  append(import_path, ast.to_path_name(ctx.path))
  for _, imported_module_path in ctx.current.references
  {
    imported_module_path_name := ast.to_path_name(imported_module_path[:])
    _, found_module := slice.linear_search(import_path[:], imported_module_path_name)
    if found_module
    {
      fmt.printfln("Cylic import detected: '%s' imported at path %s", imported_module_path_name, import_path^)
      return false
    }

    imported_module_ctx: type_checking_context =
    {
      root = ctx.root,
      current = ast.get_module(ctx.root, imported_module_path[:]),
      path = imported_module_path[:]
    }
    type_check_cyclic_imports(&imported_module_ctx, import_path) or_return
  }
  pop(import_path)

  return true
}
