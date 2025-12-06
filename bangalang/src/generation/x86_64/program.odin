package x86_64

import "core:fmt"
import "core:slice"
import "core:strings"

import "../../ast"
import ".."
import "../glsl"

generate_program :: proc(ctx: ^generation.gen_context)
{
  output: output
  program: strings.Builder
  strings.builder_init(&program)
  defer strings.builder_destroy(&program)

  fmt.sbprintln(&program, "section .text")
  fmt.sbprintln(&program, "global _start")
  fmt.sbprintln(&program, "_start:")

  generated_import_names: [dynamic]string
  generate_main_statements(ctx, output, ctx.path, &generated_import_names)

  fmt.sbprintln(&ctx.output, "  ; default exit")
  fmt.sbprintln(&ctx.output, "  mov rax, 60 ; syscall: exit")
  fmt.sbprintln(&ctx.output, "  mov rdi, 0 ; arg0: exit_code")
  fmt.sbprintln(&ctx.output, "  syscall ; call kernel")

  fmt.sbprintln(&ctx.output, "panic_out_of_bounds:")
  fmt.sbprintln(&ctx.output, "  mov rax, 1 ; syscall: print")
  fmt.sbprintln(&ctx.output, "  mov rdi, 1 ; arg0: fd (stdout)")
  fmt.sbprintln(&ctx.output, "  mov rsi, panic_out_of_bounds_message ; arg1: buffer")
  fmt.sbprintln(&ctx.output, "  mov rdx, 27 ; arg2: count")
  fmt.sbprintln(&ctx.output, "  syscall ; call kernel")
  fmt.sbprintln(&ctx.output, "  mov rax, 60 ; syscall: exit")
  fmt.sbprintln(&ctx.output, "  mov rdi, 1 ; arg0: exit_code")
  fmt.sbprintln(&ctx.output, "  syscall ; call kernel")
  fmt.sbprintln(&ctx.output, "  ret ; return")

  fmt.sbprintln(&ctx.output, "panic_negative_slice_length:")
  fmt.sbprintln(&ctx.output, "  mov rax, 1 ; syscall: print")
  fmt.sbprintln(&ctx.output, "  mov rdi, 1 ; arg0: fd (stdout)")
  fmt.sbprintln(&ctx.output, "  mov rsi, panic_negative_slice_length_message ; arg1: buffer")
  fmt.sbprintln(&ctx.output, "  mov rdx, 29 ; arg2: count")
  fmt.sbprintln(&ctx.output, "  syscall ; call kernel")
  fmt.sbprintln(&ctx.output, "  mov rax, 60 ; syscall: exit")
  fmt.sbprintln(&ctx.output, "  mov rdi, 1 ; arg0: exit_code")
  fmt.sbprintln(&ctx.output, "  syscall ; call kernel")
  fmt.sbprintln(&ctx.output, "  ret ; return")

  fmt.sbprintln(&ctx.output, "core.$lib.globals.$module.cmpxchg:")
  fmt.sbprintln(&ctx.output, "  mov rbx, [rsp + 16] ; dereference")
  fmt.sbprintln(&ctx.output, "  mov eax, [rsp + 12] ; copy")
  fmt.sbprintln(&ctx.output, "  mov ecx, [rsp + 8] ; copy")
  fmt.sbprintln(&ctx.output, "  lock cmpxchg [rbx], ecx ; compare and exchange")
  fmt.sbprintln(&ctx.output, "  setz [rsp + 24] ; assign return value")
  fmt.sbprintln(&ctx.output, "  ret ; return")

  generated_procedure_names: [dynamic]string
  for _, lib in ctx.root.children
  {
    for _, module in lib.children
    {
      generate_procedures(ctx, &module.references, &generated_procedure_names)
    }
  }

  fmt.sbprintln(&ctx.output, "section .data")
  fmt.sbprintln(&ctx.output, "  f32_sign_mask: dd 0x80000000")
  fmt.sbprintln(&ctx.output, "  f64_sign_mask: dq 0x8000000000000000")
  fmt.sbprintln(&ctx.output, "  panic_out_of_bounds_message: db \"Panic! Index out of bounds\", 10")
  fmt.sbprintln(&ctx.output, "  panic_negative_slice_length_message: db \"Panic! Negative slice length\", 10")
  for f32_literal, index in ctx.f32_literals
  {
    final_f32 := f32_literal
    if strings.index_rune(final_f32, '.') == -1
    {
      final_f32 = strings.concatenate({ final_f32, "." })
    }
    fmt.sbprintfln(&ctx.output, "  f32_%i: dd %s", index, final_f32)
  }
  for f64_literal, index in ctx.f64_literals
  {
    final_f64 := f64_literal
    if strings.index_rune(final_f64, '.') == -1
    {
      final_f64 = strings.concatenate({ final_f64, "." })
    }
    fmt.sbprintfln(&ctx.output, "  f64_%i: dq %s", index, final_f64)
  }
  for string_literal, index in ctx.string_literals
  {
    final_string, _ := strings.replace_all(string_literal, "\\n", "\", 10, \"")
    final_string, _ = strings.replace_all(final_string, "\\t", "\", 9, \"")
    fmt.sbprintfln(&ctx.output, "  string_%i$raw: db %s", index, final_string)
    fmt.sbprintfln(&ctx.output, "  string_%i: dq string_%i$raw, $ - string_%i$raw", index, index, index)
  }
  for cstring_literal, index in ctx.cstring_literals
  {
    final_cstring, _ := strings.replace_all(cstring_literal, "\\n", "\", 10, \"")
    final_cstring, _ = strings.replace_all(final_cstring, "\\t", "\", 9, \"")
    fmt.sbprintfln(&ctx.output, "  cstring_%i: db %s, 0", index, final_cstring)
  }

  generate_static_vars(ctx)
}

generate_main_statements :: proc(ctx: ^generation.gen_context, output: ^output, path: []string, generated_import_names: ^[dynamic]string)
{
  module_path_name := ast.to_path_name(path)
  _, found_generated_module := slice.linear_search(generated_import_names[:], module_path_name)
  if found_generated_module
  {
    return
  }

  append(generated_import_names, module_path_name)

  module := ast.get_module(ctx.root, path)
  for _, imported_module_path in module.references
  {
    generate_main_statements(ctx, output, imported_module_path[:], generated_import_names)
  }

  ctx.current = module
  ctx.path = path

  generate_statements(ctx, output, module.statements[:])
}

generate_procedures :: proc(ctx: ^generation.gen_context, references: ^map[string][dynamic]string, generated_procedure_names: ^[dynamic]string)
{
  for _, reference in references
  {
    path_name := ast.to_path_name(reference[:])

    _, found_generated_procedure := slice.linear_search(generated_procedure_names[:], path_name)
    if found_generated_procedure
    {
      continue
    }

    append(generated_procedure_names, path_name)

    procedure := ast.get_scope(ctx.root, reference[:])
    node := procedure.statements[0]
    lhs_node := node.children[0]

    // TODO better
    switch lhs_node.allocator.value
    {
    case "code":
      {
        procedure_ctx: generation.gen_context =
        {
          root = ctx.root,
          current = procedure,
          path = reference[:],
          output = ctx.output
        }

        generate_procedure(&procedure_ctx, node)

        ctx.output = procedure_ctx.output

        generate_procedures(ctx, &procedure.references, generated_procedure_names)
      }
    case "compute_shader":
      {
        procedure_ctx: generation.gen_context =
        {
          program = ctx.root,
          path = reference[:]
        }

        strings.builder_init(&procedure_ctx.output)

        glsl.generate_program(&procedure_ctx, node)

        static_var_node := ast.make_node({ type = .assignment_statement })
        append(&static_var_node.children, ast.make_node({ type = .identifier, value = path_name, allocator = lhs_node.allocator }))
        append(&static_var_node.children, ast.make_node({ type = .assign, value = "=" }))
        append(&static_var_node.children, ast.make_node({ type = .string_literal, value = strings.to_string(procedure_ctx.output) }))
        ctx.root.static_vars[path_name] = static_var_node
      }
    case "extern":
      fmt.sbprintfln(&ctx.output, "extern %s", lhs_node.value)
    case "none":
      // Do nothing
    case:
      assert(false, "Failed to generate procedures")
    }
  }
}

generate_static_vars :: proc(ctx: ^generation.gen_context)
{
  glsl_kernel_names: [dynamic]string
  defer delete(glsl_kernel_names)

  for _, static_var_node in ctx.static_vars
  {
    lhs_node := static_var_node.children[0]

    // TODO better
    if lhs_node.allocator.value == "compute_shader"
    {
      rhs_node := static_var_node.children[2]

      final_string, _ := strings.replace_all(rhs_node.value, "\n", "\", 10, \"")
      fmt.sbprintfln(&ctx.output, "  %s$raw: db \"%s\"", static_var_name, final_string)
      fmt.sbprintfln(&ctx.output, "  %s: dq %s$raw, $ - %s$raw", static_var_name, static_var_name, static_var_name)

      append(&glsl_kernel_names, static_var_name)
    }
    else
    {
      lhs_type_node := lhs_node.data_type
      if lhs_node.directive == "#align4" || lhs_type_node.directive == "#align4"
      {
        fmt.sbprintln(&ctx.output, "  align 4")
      }

      size := to_byte_size(lhs_type_node)
      fmt.sbprintfln(&ctx.output, "  %s: times %i db 0", static_var_name, size)
    }
  }

  if len(glsl_kernel_names) > 0
  {
    fmt.sbprint(&ctx.output, "  core.$lib.boomstick.$module.glsl_kernels$raw: dq")
    for glsl_kernel_name, index in glsl_kernel_names
    {
      if index > 0
      {
        fmt.sbprint(&ctx.output, ",")
      }
      fmt.sbprintf(&ctx.output, " %s", glsl_kernel_name)
    }
    fmt.sbprintln(&ctx.output, "")
    fmt.sbprintfln(&ctx.output, "  core.$lib.boomstick.$module.glsl_kernels: dq core.$lib.boomstick.$module.glsl_kernels$raw, %i", len(glsl_kernel_names))
  }
  else
  {
    fmt.sbprintln(&ctx.output, "  core.$lib.boomstick.$module.glsl_kernels: dq 0, 0")
  }
}
