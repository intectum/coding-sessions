package type_checking

import "core:fmt"
import "core:os"
import "core:strings"

import "../ast"
import "../program"

type_check_module :: proc(ctx: ^type_checking_context) -> bool
{
  ctx.identifiers["atomic_i8"] = { type = .type, value = "atomic_i8" }
  ctx.identifiers["atomic_i16"] = { type = .type, value = "atomic_i16" }
  ctx.identifiers["atomic_i32"] = { type = .type, value = "atomic_i32" }
  ctx.identifiers["atomic_i64"] = { type = .type, value = "atomic_i64" }
  ctx.identifiers["bool"] = { type = .type, value = "bool" }
  ctx.identifiers["cint"] = { type = .type, value = "cint" }
  ctx.identifiers["cstring"] = { type = .type, value = "cstring" }
  ctx.identifiers["f32"] = { type = .type, value = "f32" }
  ctx.identifiers["f64"] = { type = .type, value = "f64" }
  ctx.identifiers["i8"] = { type = .type, value = "i8" }
  ctx.identifiers["i16"] = { type = .type, value = "i16" }
  ctx.identifiers["i32"] = { type = .type, value = "i32" }
  ctx.identifiers["i64"] = { type = .type, value = "i64" }

  string_type_node := ast.node { type = .type, value = "[slice]" }
  append(&string_type_node.children, ast.node { type = .type, value = "i8" })
  ctx.identifiers["string"] = string_type_node

  import_proc := ast.node { type = .identifier, value = "import" }
  append(&import_proc.children, ast.node { type = .type, value = "[procedure]" })
  append(&import_proc.children[0].children, ast.node { type = .type, value = "[parameters]" })
  append(&import_proc.children[0].children[0].children, ast.node { type = .identifier, value = "name" })
  append(&import_proc.children[0].children[0].children[0].children, ctx.identifiers["string"])
  append(&import_proc.children[0].children, ast.node { type = .type, value = "[module]" })
  ctx.identifiers["import"] = import_proc

  cmpxchg := ast.node { type = .identifier, value = "cmpxchg" }
  append(&cmpxchg.children, ast.node { type = .type, value = "[procedure]" })
  append(&cmpxchg.children[0].children, ast.node { type = .type, value = "[parameters]" })
  append(&cmpxchg.children[0].children[0].children, ast.node { type = .identifier, value = "value" })
  append(&cmpxchg.children[0].children[0].children[0].children, ast.node { type = .reference })
  append(&cmpxchg.children[0].children[0].children[0].children[0].children, ast.node { type = .type, value = "i32" })
  append(&cmpxchg.children[0].children[0].children, ast.node { type = .identifier, value = "expected" })
  append(&cmpxchg.children[0].children[0].children[1].children, ast.node { type = .type, value = "i32" })
  append(&cmpxchg.children[0].children[0].children, ast.node { type = .identifier, value = "replacement" })
  append(&cmpxchg.children[0].children[0].children[2].children, ast.node { type = .type, value = "i32" })
  append(&cmpxchg.children[0].children, ast.node { type = .type, value = "bool" })
  ctx.identifiers["cmpxchg"] = cmpxchg

  for &statement in ctx.program.procedures[ctx.module_name].statements
  {
    if !ast.is_import_statement(&statement)
    {
      continue
    }

    lhs_node := &statement.children[0]
    reference := lhs_node.value
    name := strings.concatenate({ "stdlib/", reference, ".bang" })

    if name in ctx.program.modules
    {
      continue
    }

    code_data, code_ok := os.read_entire_file(name)
    if !code_ok
    {
      fmt.printfln("Failed to read module file %s", name)
      return false
    }

    program.load_module(ctx.program, name, string(code_data)) or_return

    imported_module_ctx: type_checking_context =
    {
      program = ctx.program,
      module_name = name,
      procedure_name = name
    }
    type_check_module(&imported_module_ctx) or_return

    module := &ctx.program.modules[ctx.module_name]
    module.imports[reference] = name
  }

  for &statement in ctx.program.procedures[ctx.module_name].statements
  {
    resolve_types(&statement, ctx)

    if !ast.is_type_alias_statement(&statement)
    {
      continue
    }

    lhs_node := &statement.children[0]
    rhs_node := &statement.children[2]

    name := lhs_node.value
    lhs_node^ = rhs_node^
    ctx.identifiers[name] = lhs_node^
  }

  procedure_names: [dynamic]string
  for &statement in ctx.program.procedures[ctx.module_name].statements
  {
    if !ast.is_static_procedure_statement(&statement)
    {
      continue
    }

    lhs_node := &statement.children[0]
    lhs_type_node := ast.get_type(lhs_node)

    ctx.identifiers[lhs_node.value] = lhs_node^

    procedure: program.procedure
    append(&procedure.statements, statement)
    ctx.program.procedures[lhs_node.value] = procedure

    append(&procedure_names, lhs_node.value)
  }

  main_procedure := &ctx.program.procedures[ctx.module_name]
  for &statement in main_procedure.statements
  {
    if ast.is_type_alias_statement(&statement) || ast.is_static_procedure_statement(&statement)
    {
      continue
    }

    type_check_statement(&statement, ctx) or_return
  }

  module := &ctx.program.modules[ctx.module_name]
  module.identifiers = ctx.identifiers

  for procedure_name in procedure_names
  {
    procedure := &ctx.program.procedures[procedure_name]
    procedure_ctx := copy_type_checking_context(ctx, false)
    procedure_ctx.procedure_name = procedure_name

    for &statement in procedure.statements
    {
      type_check_statement(&statement, &procedure_ctx) or_return
    }
  }

  return true
}
