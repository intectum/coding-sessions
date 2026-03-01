package kernels

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "../../ast"
import "../../program"
import ".."
import "../glsl"

generate_program :: proc(ctx: ^generation.gen_context)
{
  generated_procedure_names: [dynamic]string
  for qualified_module_name in ctx.program.modules
  {
    main_procedure := &ctx.program.procedures[qualified_module_name]
    generate_procedures(ctx, main_procedure.references[:], &generated_procedure_names)
  }
}

generate_procedures :: proc(ctx: ^generation.gen_context, references: [][dynamic]string, generated_procedure_names: ^[dynamic]string)
{
  for reference in references
  {
    qualified_name := program.get_qualified_name(reference[:])

    _, found_generated_procedure := slice.linear_search(generated_procedure_names[:], qualified_name)
    if found_generated_procedure
    {
      continue
    }

    append(generated_procedure_names, qualified_name)

    procedure := &ctx.program.procedures[qualified_name]
    node := procedure.statements[0]
    lhs_node := node.children[0]

    // TODO better
    switch lhs_node.allocator.value
    {
    case "code":
      generate_procedures(ctx, procedure.references[:], generated_procedure_names)
    case "compute_shader":
      procedure_ctx: generation.gen_context =
      {
        program = ctx.program,
        path = reference[:]
      }

      strings.builder_init(&procedure_ctx.output)
      defer strings.builder_destroy(&procedure_ctx.output)

      glsl.generate_program(&procedure_ctx, node)

      file, file_error := os.open(fmt.aprintf("bin/%s.glsl", qualified_name), os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o666)
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
