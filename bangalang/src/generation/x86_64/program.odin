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

  generate_statements(ctx)

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
  append(&generated_procedure_names, "import")
  append(&generated_procedure_names, "cmpxchg") // TODO yuck

  main_procedure := &ctx.program.procedures[ctx.procedure_name]
  generate_procedures(ctx, &main_procedure.references, &generated_procedure_names)

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
    fmt.sbprintfln(&ctx.output, "  string_%i_data: db %s", index, final_string)
    fmt.sbprintfln(&ctx.output, "  string_%i_data_len: equ $ - string_%i_data", index, index)
    fmt.sbprintfln(&ctx.output, "  string_%i: dq string_%i_data, string_%i_data_len", index, index, index)
  }
  for cstring_literal, index in ctx.program.cstring_literals
  {
    final_cstring, _ := strings.replace_all(cstring_literal, "\\n", "\", 10, \"")
    fmt.sbprintfln(&ctx.output, "  cstring_%i: db %s, 0", index, final_cstring)
  }
  for static_var, index in ctx.program.static_vars
  {
    final_cstring, _ := strings.replace_all(ctx.program.static_vars[static_var], "\n", "\", 10, \"")
    fmt.sbprintfln(&ctx.output, "  %s: db \"%s\", 0", static_var, final_cstring)
  }

  generate_static_vars(ctx)
}

generate_statements :: proc(ctx: ^generation.gen_context)
{
  for module_name in ctx.program.modules
  {
    main_procedure := &ctx.program.procedures[module_name]
    for &statement in main_procedure.statements
    {
      if ast.is_link_statement(&statement) || ast.is_import_statement(&statement) || ast.is_type_alias_statement(&statement) || ast.is_static_assignment_statement(&statement)
      {
        continue
      }

      generate_statement(ctx, &statement)
    }
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
      ctx.program.static_vars[procedure_name] = strings.to_string(procedure_ctx.output)
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
  for module_name in ctx.program.modules
  {
    main_procedure := &ctx.program.procedures[module_name]
    for &statement in main_procedure.statements
    {
      if ast.is_static_assignment_statement(&statement) && !ast.is_static_procedure_statement(&statement)
      {
        lhs_node := &statement.children[0]
        rhs_node := &statement.children[2]

        size := to_byte_size(ast.get_type(lhs_node))
        fmt.sbprintfln(&ctx.output, "  %s: %s %s", lhs_node.value, to_define_size(size), rhs_node.value)
      }
    }
  }
}
