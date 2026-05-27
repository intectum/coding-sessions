package kernels

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "../../ast"
import ".."
import "../glsl"

generate_program :: proc(ctx: ^generation.gen_context)
{
  generated_procedure_names: [dynamic]string
  for lib_name in ctx.root.children
  {
    lib := ctx.root.children[lib_name]
    for module_name in lib.children
    {
      module := lib.children[module_name]
      generate_procedures(ctx, &module.references, &generated_procedure_names)
    }
  }
}

generate_procedures :: proc(ctx: ^generation.gen_context, references: ^[dynamic]ast.reference, generated_procedure_names: ^[dynamic]string)
{
  for reference in references
  {
    if len(reference.path) == 2 do continue

    procedure_name := ast.get_scope_name(reference.path[:])
    _, found_generated_procedure := slice.linear_search(generated_procedure_names[:], procedure_name)
    if found_generated_procedure
    {
      continue
    }

    append(generated_procedure_names, procedure_name)

    procedure := ast.get_scope(ctx.root, reference.path[:])
    node := procedure.statements[0]
    lhs_node := node.children[0]

    // TODO better
    switch lhs_node.allocator.value
    {
    case "code":
      generate_procedures(ctx, &procedure.references, generated_procedure_names)
    case "compute_shader":
      procedure_ctx: generation.gen_context =
      {
        root = ctx.root,
        scope = procedure,
      }

      strings.builder_init(&procedure_ctx.output)
      defer strings.builder_destroy(&procedure_ctx.output)

      glsl.generate_program(&procedure_ctx, node)

      file, file_error := os.open(fmt.aprintf("bin/%s.glsl", procedure_name), os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o666)
      if file_error != nil
      {
        fmt.println("Failed to open asm file")
        os.exit(1)
      }
      defer os.close(file)

      fmt.fprint(file, strings.to_string(procedure_ctx.output))
    case "extern":
      fmt.sbprintfln(&ctx.output, "extern %s", lhs_node.value)
    case "none":
      // Do nothing
    case:
      assert(false, "Failed to generate procedures")
    }
  }
}
