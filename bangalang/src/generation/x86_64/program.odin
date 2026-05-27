package x86_64

import "core:fmt"
import "core:slice"
import "core:strings"

import "../../ast"
import "../../loading"
import ".."
import "../glsl"

generate_program :: proc(ctx: ^generation.gen_context)
{
  ctx.root.children["[f32_literals]"] = {}
  ctx.root.children["[f64_literals]"] = {}
  ctx.root.children["[string_literals]"] = {}
  ctx.root.children["[cstring_literals]"] = {}
  ctx.root.children["[static_vars]"] = {}

  fmt.sbprintln(&ctx.output, "section .text")
  fmt.sbprintln(&ctx.output, "global _start")
  fmt.sbprintln(&ctx.output, "_start:")

  generated_import_names: [dynamic]string
  generate_main_statements(ctx, ctx.scope.path, &generated_import_names)

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
  for lib_name in ctx.root.children
  {
    lib := &ctx.root.children[lib_name]
    for module_name in lib.children
    {
      module := &lib.children[module_name]
      generate_procedures(ctx, &module.references, &generated_procedure_names)
    }
  }

  fmt.sbprintln(&ctx.output, "section .data")
  fmt.sbprintln(&ctx.output, "  f32_sign_mask: dd 0x80000000")
  fmt.sbprintln(&ctx.output, "  f64_sign_mask: dq 0x8000000000000000")
  fmt.sbprintln(&ctx.output, "  panic_out_of_bounds_message: db \"Panic! Index out of bounds\", 10")
  fmt.sbprintln(&ctx.output, "  panic_negative_slice_length_message: db \"Panic! Negative slice length\", 10")
  for f32_literal, index in ctx.root.children["[f32_literals]"].statements
  {
    f32_value := f32_literal.value
    if strings.index_rune(f32_value, '.') == -1
    {
      f32_value = strings.concatenate({ f32_value, "." })
    }
    fmt.sbprintfln(&ctx.output, "  f32_%i: dd %s", index, f32_value)
  }
  for f64_literal, index in ctx.root.children["[f64_literals]"].statements
  {
    final_f64 := f64_literal.value
    if strings.index_rune(final_f64, '.') == -1
    {
      final_f64 = strings.concatenate({ final_f64, "." })
    }
    fmt.sbprintfln(&ctx.output, "  f64_%i: dq %s", index, final_f64)
  }
  for string_literal, index in ctx.root.children["[string_literals]"].statements
  {
    final_string, _ := strings.replace_all(string_literal.value, "\\n", "\", 10, \"")
    final_string, _ = strings.replace_all(final_string, "\\t", "\", 9, \"")
    fmt.sbprintfln(&ctx.output, "  string_%i$raw: db %s", index, final_string)
    fmt.sbprintfln(&ctx.output, "  string_%i: dq string_%i$raw, $ - string_%i$raw", index, index, index)
  }
  for cstring_literal, index in ctx.root.children["[cstring_literals]"].statements
  {
    final_cstring, _ := strings.replace_all(cstring_literal.value, "\\n", "\", 10, \"")
    final_cstring, _ = strings.replace_all(final_cstring, "\\t", "\", 9, \"")
    fmt.sbprintfln(&ctx.output, "  cstring_%i: db %s, 0", index, final_cstring)
  }

  generate_static_vars(ctx)
}

generate_main_statements :: proc(ctx: ^generation.gen_context, path: []string, generated_import_names: ^[dynamic]string)
{
  module_name := ast.get_scope_name(path)
  _, found_generated_module := slice.linear_search(generated_import_names[:], module_name)
  if found_generated_module do return

  append(generated_import_names, module_name)

  module := ast.get_scope(ctx.root, path)
  for reference in module.references
  {
    if len(reference.path) != 2 do continue;
    generate_main_statements(ctx, reference.path[:], generated_import_names)
  }

  ctx.scope = module

  generate_statements(ctx, module.statements[:])
}

generate_procedures :: proc(ctx: ^generation.gen_context, references: ^[dynamic]ast.reference, generated_procedure_names: ^[dynamic]string)
{
  for reference in references
  {
    if len(reference.path) == 2 do continue;

    procedure_name := ast.get_scope_name(reference.path[:])
    _, found_generated_procedure := slice.linear_search(generated_procedure_names[:], procedure_name)
    if found_generated_procedure do continue

    append(generated_procedure_names, procedure_name)

    procedure := ast.get_scope(ctx.root, reference.path[:])
    node := procedure.statements[0]
    lhs_node := node.children[0]

    // TODO better
    switch lhs_node.allocator.value
    {
    case "code":
      procedure_ctx: generation.gen_context =
      {
        root = ctx.root,
        scope = procedure,
        output = ctx.output
      }

      generate_procedure(&procedure_ctx, node)

      ctx.output = procedure_ctx.output

      generate_procedures(ctx, &procedure.references, generated_procedure_names)
    case "compute_shader":
      procedure_ctx: generation.gen_context =
      {
        root = ctx.root,
        scope = procedure
      }

      strings.builder_init(&procedure_ctx.output)

      glsl.generate_program(&procedure_ctx, node)

      static_var_node := ast.make_node({ type = .assignment_statement })
      append(&static_var_node.children, ast.make_node({ type = .identifier, value = procedure_name, allocator = lhs_node.allocator }))
      append(&static_var_node.children, ast.make_node({ type = .assign, value = "=" }))
      append(&static_var_node.children, ast.make_node({ type = .string_literal, value = strings.to_string(procedure_ctx.output) }))
      static_vars := &ctx.root.children["[static_vars]"]
      append(&static_vars.statements, static_var_node)
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

  for declaration in ctx.root.children["[static_vars]"].statements
  {
    lhs_node := declaration.children[0]

    // TODO better
    if lhs_node.allocator != nil && lhs_node.allocator.value == "compute_shader"
    {
      rhs_node := declaration.children[2]

      final_string, _ := strings.replace_all(rhs_node.value, "\n", "\", 10, \"")
      fmt.sbprintfln(&ctx.output, "  %s$raw: db \"%s\"", lhs_node.value, final_string)
      fmt.sbprintfln(&ctx.output, "  %s: dq %s$raw, $ - %s$raw", lhs_node.value, lhs_node.value, lhs_node.value)

      append(&glsl_kernel_names, lhs_node.value)
    }
    else
    {
      lhs_type_node := lhs_node.data_type
      if lhs_node.directive == "#align4" || lhs_type_node.directive == "#align4"
      {
        fmt.sbprintln(&ctx.output, "  align 4")
      }

      size := to_byte_size(lhs_type_node)
      fmt.sbprintfln(&ctx.output, "  %s: times %i db 0", lhs_node.value, size)
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
