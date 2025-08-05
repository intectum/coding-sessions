package generation

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

import "../ast"

generate_program :: proc(ctx: ^gen_context, asm_path: string)
{
  file, file_error := os.open(asm_path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o666)
  if file_error != nil
  {
    fmt.println("Failed to open asm file")
    os.exit(1)
  }
  defer os.close(file)

  fmt.fprintln(file, "section .text")
  fmt.fprintln(file, "global _start")
  fmt.fprintln(file, "_start:")

  generate_statements(file, ctx)

  fmt.fprintln(file, "  ; default exit")
  fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
  fmt.fprintln(file, "  mov rdi, 0 ; arg0: exit_code")
  fmt.fprintln(file, "  syscall ; call kernel")

  fmt.fprintln(file, "cmpxchg:")
  fmt.fprintln(file, "  mov rbx, [rsp + 16] ; dereference")
  fmt.fprintln(file, "  mov eax, [rsp + 12] ; copy")
  fmt.fprintln(file, "  mov ecx, [rsp + 8] ; copy")
  fmt.fprintln(file, "  lock cmpxchg [rbx], ecx ; compare and exchange")
  fmt.fprintln(file, "  setz [rsp + 24] ; assign return value")
  fmt.fprintln(file, "  ret ; return")

  fmt.fprintln(file, "panic_out_of_bounds:")
  fmt.fprintln(file, "  mov rax, 1 ; syscall: print")
  fmt.fprintln(file, "  mov rdi, 1 ; arg0: fd (stdout)")
  fmt.fprintln(file, "  mov rsi, panic_out_of_bounds_message ; arg1: buffer")
  fmt.fprintln(file, "  mov rdx, 27 ; arg2: count")
  fmt.fprintln(file, "  syscall ; call kernel")
  fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
  fmt.fprintln(file, "  mov rdi, 1 ; arg0: exit_code")
  fmt.fprintln(file, "  syscall ; call kernel")
  fmt.fprintln(file, "  ret ; return")

  fmt.fprintln(file, "panic_negative_slice_length:")
  fmt.fprintln(file, "  mov rax, 1 ; syscall: print")
  fmt.fprintln(file, "  mov rdi, 1 ; arg0: fd (stdout)")
  fmt.fprintln(file, "  mov rsi, panic_negative_slice_length_message ; arg1: buffer")
  fmt.fprintln(file, "  mov rdx, 29 ; arg2: count")
  fmt.fprintln(file, "  syscall ; call kernel")
  fmt.fprintln(file, "  mov rax, 60 ; syscall: exit")
  fmt.fprintln(file, "  mov rdi, 1 ; arg0: exit_code")
  fmt.fprintln(file, "  syscall ; call kernel")
  fmt.fprintln(file, "  ret ; return")

  generated_procedure_names: [dynamic]string
  append(&generated_procedure_names, "import")
  append(&generated_procedure_names, "cmpxchg") // TODO yuck

  main_procedure := &ctx.program.procedures[ctx.procedure_name]
  generate_procedures(file, &main_procedure.references, ctx, &generated_procedure_names)

  fmt.fprintln(file, "section .data")
  fmt.fprintln(file, "  f32_sign_mask: dd 0x80000000")
  fmt.fprintln(file, "  f64_sign_mask: dq 0x8000000000000000")
  fmt.fprintln(file, "  panic_out_of_bounds_message: db \"Panic! Index out of bounds\", 10")
  fmt.fprintln(file, "  panic_negative_slice_length_message: db \"Panic! Negative slice length\", 10")
  for data_section_f32, index in ctx.data_section_f32s
  {
    final_f32 := data_section_f32
    if strings.index_rune(final_f32, '.') == -1
    {
      final_f32 = strings.concatenate({ final_f32, "." })
    }
    fmt.fprintfln(file, "  f32_%i: dd %s", index, final_f32)
  }
  for data_section_f64, index in ctx.data_section_f64s
  {
    final_f64 := data_section_f64
    if strings.index_rune(final_f64, '.') == -1
    {
      final_f64 = strings.concatenate({ final_f64, "." })
    }
    fmt.fprintfln(file, "  f64_%i: dq %s", index, final_f64)
  }
  for data_section_string, index in ctx.data_section_strings
  {
    final_string, _ := strings.replace_all(data_section_string, "\\n", "\", 10, \"")
    fmt.fprintfln(file, "  string_%i_data: db %s", index, final_string)
    fmt.fprintfln(file, "  string_%i_data_len: equ $ - string_%i_data", index, index)
    fmt.fprintfln(file, "  string_%i: dq string_%i_data, string_%i_data_len", index, index, index)
  }
  for data_section_cstring, index in ctx.data_section_cstrings
  {
    final_cstring, _ := strings.replace_all(data_section_cstring, "\\n", "\", 10, \"")
    fmt.fprintfln(file, "  cstring_%i: db %s, 0", index, final_cstring)
  }

  generate_static_vars(file, main_procedure.statements[:], ctx)
}

generate_statements :: proc(file: os.Handle, ctx: ^gen_context)
{
  for module_name in ctx.program.modules
  {
    main_procedure := &ctx.program.procedures[module_name]
    for &statement in main_procedure.statements
    {
      if ast.is_import_statement(&statement) || ast.is_type_alias_statement(&statement) || ast.is_static_assignment_statement(&statement)
      {
        continue
      }

      generate_statement(file, &statement, ctx)
    }
  }
}

generate_procedures :: proc(file: os.Handle, procedure_names: ^[dynamic]string, ctx: ^gen_context, generated_procedure_names: ^[dynamic]string)
{
  for procedure_name in procedure_names
  {
    _, found_generated_procedure := slice.linear_search(generated_procedure_names[:], procedure_name)
    if found_generated_procedure
    {
      continue
    }

    ctx.procedure_name = procedure_name
    append(generated_procedure_names, procedure_name)

    procedure := &ctx.program.procedures[procedure_name]
    generate_procedure(file, &procedure.statements[0], ctx)

    generate_procedures(file, &procedure.references, ctx, generated_procedure_names)
  }
}

generate_static_vars :: proc(file: os.Handle, statements: []ast.node, ctx: ^gen_context)
{
  for &statement in statements
  {
    if ast.is_static_assignment_statement(&statement) && !ast.is_static_procedure_statement(&statement)
    {
      lhs_node := &statement.children[0]
      rhs_node := &statement.children[2]

      size := to_byte_size(ast.get_type(lhs_node))
      fmt.fprintfln(file, "  %s: %s %s", lhs_node.value, to_define_size(size), rhs_node.value)
    }
  }
}
