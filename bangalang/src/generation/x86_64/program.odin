package x86_64

import "core:fmt"
import "core:slice"
import "core:strings"

import "../../ast"
import ".."
import "../glsl"

generate_program :: proc(ctx: ^generation.gen_context)
{
  fmt.sbprintln(&ctx.output, "section .text")
  fmt.sbprintln(&ctx.output, "global _start")
  fmt.sbprintln(&ctx.output, "_start:")

  generated_import_names: [dynamic]string

  generate_statements(ctx, ctx.procedure_name, &generated_import_names)

  fmt.sbprintln(&ctx.output, "  ; default exit")
  fmt.sbprintln(&ctx.output, "  mov rax, 60 ; syscall: exit")
  fmt.sbprintln(&ctx.output, "  mov rdi, 0 ; arg0: exit_code")
  fmt.sbprintln(&ctx.output, "  syscall ; call kernel")

  fmt.sbprintln(&ctx.output, "cmpxchg:")
  fmt.sbprintln(&ctx.output, "  mov rbx, [rsp + 16] ; dereference")
  fmt.sbprintln(&ctx.output, "  mov eax, [rsp + 12] ; copy")
  fmt.sbprintln(&ctx.output, "  mov ecx, [rsp + 8] ; copy")
  fmt.sbprintln(&ctx.output, "  lock cmpxchg [rbx], ecx ; compare and exchange")
  fmt.sbprintln(&ctx.output, "  setz [rsp + 24] ; assign return value")
  fmt.sbprintln(&ctx.output, "  ret ; return")

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

  generated_procedure_names: [dynamic]string
  append(&generated_procedure_names, "cmpxchg") // TODO yuck
  append(&generated_procedure_names, "import")
  append(&generated_procedure_names, "link")

  for module_name in ctx.program.modules
  {
    main_procedure := &ctx.program.procedures[module_name]
    generate_procedures(ctx, &main_procedure.references, &generated_procedure_names)
  }

  fmt.sbprintln(&ctx.output, "section .data")
  fmt.sbprintln(&ctx.output, "  f32_sign_mask: dd 0x80000000")
  fmt.sbprintln(&ctx.output, "  f64_sign_mask: dq 0x8000000000000000")
  fmt.sbprintln(&ctx.output, "  panic_out_of_bounds_message: db \"Panic! Index out of bounds\", 10")
  fmt.sbprintln(&ctx.output, "  panic_negative_slice_length_message: db \"Panic! Negative slice length\", 10")
  for f32_literal, index in ctx.program.f32_literals
  {
    final_f32 := f32_literal
    if strings.index_rune(final_f32, '.') == -1
    {
      final_f32 = strings.concatenate({ final_f32, "." })
    }
    fmt.sbprintfln(&ctx.output, "  f32_%i: dd %s", index, final_f32)
  }
  for f64_literal, index in ctx.program.f64_literals
  {
    final_f64 := f64_literal
    if strings.index_rune(final_f64, '.') == -1
    {
      final_f64 = strings.concatenate({ final_f64, "." })
    }
    fmt.sbprintfln(&ctx.output, "  f64_%i: dq %s", index, final_f64)
  }
  for string_literal, index in ctx.program.string_literals
  {
    final_string, _ := strings.replace_all(string_literal, "\\n", "\", 10, \"")
    fmt.sbprintfln(&ctx.output, "  string_%i$raw: db %s", index, final_string)
    fmt.sbprintfln(&ctx.output, "  string_%i: dq string_%i$raw, $ - string_%i$raw", index, index, index)
  }
  for cstring_literal, index in ctx.program.cstring_literals
  {
    final_cstring, _ := strings.replace_all(cstring_literal, "\\n", "\", 10, \"")
    fmt.sbprintfln(&ctx.output, "  cstring_%i: db %s, 0", index, final_cstring)
  }

  generate_static_vars(ctx)
}

generate_statements :: proc(ctx: ^generation.gen_context, module_name: string, generated_import_names: ^[dynamic]string)
{
  _, found_generated_module := slice.linear_search(generated_import_names[:], module_name)
  if found_generated_module
  {
    return
  }

  append(generated_import_names, module_name)

  module := &ctx.program.modules[module_name]
  for import_name in module.imports
  {
    generate_statements(ctx, module.imports[import_name], generated_import_names)
  }

  main_procedure := &ctx.program.procedures[module_name]
  for &statement in main_procedure.statements
  {
    if ast.is_link_statement(&statement) || ast.is_import_statement(&statement) || ast.is_type_alias_statement(&statement) || ast.is_static_procedure_statement(&statement)
    {
      continue
    }

    generate_statement(ctx, &statement)
  }
}

generate_procedures :: proc(ctx: ^generation.gen_context, procedure_names: ^[dynamic]string, generated_procedure_names: ^[dynamic]string)
{
  for procedure_name in procedure_names
  {
    _, found_generated_procedure := slice.linear_search(generated_procedure_names[:], procedure_name)
    if found_generated_procedure
    {
      continue
    }

    append(generated_procedure_names, procedure_name)

    procedure := &ctx.program.procedures[procedure_name]
    node := &procedure.statements[0]
    lhs_node := &node.children[0]
    if lhs_node.allocator == "glsl"
    {
      procedure_ctx: generation.gen_context =
      {
        program = ctx.program,
        procedure_name = procedure_name
      }

      strings.builder_init(&procedure_ctx.output)

      glsl.generate_program(&procedure_ctx, node)

      static_var_node: ast.node = { type = .assignment }
      append(&static_var_node.children, ast.node { type = .identifier, value = procedure_name, allocator = "glsl" })
      append(&static_var_node.children, ast.node { type = .assign, value = "=" })
      append(&static_var_node.children, ast.node { type = .string_, value = strings.to_string(procedure_ctx.output) })
      append(&ctx.program.static_vars, static_var_node)
    }
    else
    {
      procedure_ctx: generation.gen_context =
      {
        program = ctx.program,
        procedure_name = procedure_name,
        output = ctx.output
      }

      generate_procedure(&procedure_ctx, node)

      ctx.output = procedure_ctx.output

      generate_procedures(ctx, &procedure.references, generated_procedure_names)
    }
  }
}

generate_static_vars :: proc(ctx: ^generation.gen_context)
{
  glsl_kernel_names: [dynamic]string
  defer delete(glsl_kernel_names)

  for static_var_node in ctx.program.static_vars
  {
    lhs_node := &static_var_node.children[0]

    if lhs_node.allocator == "glsl"
    {
      rhs_node := &static_var_node.children[2]

      final_string, _ := strings.replace_all(rhs_node.value, "\n", "\", 10, \"")
      fmt.sbprintfln(&ctx.output, "  %s$raw: db \"%s\"", lhs_node.value, final_string)
      fmt.sbprintfln(&ctx.output, "  %s: dq %s$raw, $ - %s$raw", lhs_node.value, lhs_node.value, lhs_node.value)

      append(&glsl_kernel_names, lhs_node.value)
    }
    else
    {
      size := to_byte_size(ast.get_type(lhs_node))
      fmt.sbprintfln(&ctx.output, "  %s: times %i db 0", lhs_node.value, size)
    }
  }

  if len(glsl_kernel_names) > 0
  {
    fmt.sbprint(&ctx.output, "  glsl_kernels$raw: dq")
    for glsl_kernel_name, index in glsl_kernel_names
    {
      if index > 0
      {
        fmt.sbprint(&ctx.output, ",")
      }
      fmt.sbprintf(&ctx.output, " %s", glsl_kernel_name)
    }
    fmt.sbprintln(&ctx.output, "")
    fmt.sbprintfln(&ctx.output, "  glsl_kernels: dq glsl_kernels$raw, %i", len(glsl_kernel_names))
  }
  else
  {
    fmt.sbprintln(&ctx.output, "  glsl_kernels: dq 0, 0")
  }
}
