package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:strings"
import "core:sys/linux"

main :: proc()
{
  //run_test_suite()

  run("examples/example_01.bang", "bin/example_01")
}

run :: proc(src_path: string, bin_path: string)
{
  build(src_path, bin_path)

  os.exit(int(exec(bin_path)))
}

build :: proc(src_path: string, bin_path: string)
{
  asm_path := strings.concatenate({ bin_path, ".asm" })
  object_path := strings.concatenate({ bin_path, ".o" })

  compile(src_path, asm_path)

  nasm_command := strings.concatenate({ "nasm -f elf64 ", asm_path, " -o ", object_path })
  nasm_code := exec(nasm_command)
  if nasm_code > 0
  {
    fmt.println("Failed to assemble")
    os.exit(int(nasm_code))
  }

  // TODO don't hardcode this stuff...
  ld_command := strings.concatenate({ "ld -dynamic-linker /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ", object_path, " -o ", bin_path, " -lglfw -lGL -lGLU" })
  ld_code := exec(ld_command)
  if ld_code > 0
  {
    fmt.println("Failed to link")
    os.exit(int(ld_code))
  }
}

compile :: proc(src_path: string, asm_path: string)
{
  tokens: [dynamic]token

  stdlib_data, stdlib_ok := os.read_entire_file("src/stdlib.bang")
  if !stdlib_ok
  {
    fmt.println("Failed to read stdlib file")
    os.exit(1)
  }

  tokenize("src/stdlib.bang", string(stdlib_data), &tokens)

  src_data, src_ok := os.read_entire_file(src_path)
  if !src_ok
  {
    fmt.println("Failed to read src file")
    os.exit(1)
  }

  tokenize(src_path, string(src_data), &tokens)

  stream := token_stream { tokens = tokens[:] }
  ast_nodes, parse_ok := parse_program(&stream)
  if !parse_ok
  {
    next_token := peek_token(&stream)
    file_error("Failed to parse", next_token.file_info)
    fmt.println(stream.error)
    os.exit(1)
  }

  type_check_ok := type_check_program(ast_nodes)
  if !type_check_ok
  {
    fmt.println("Failed to type check")
    os.exit(1)
  }

  generate_program(asm_path, ast_nodes)
}

exec :: proc(command: string) -> u32
{
  return linux.WEXITSTATUS(u32(libc.system(strings.clone_to_cstring(command))))
}

run_test_suite :: proc()
{
  build("src/tests.bang", "bin/tests")
  tests_code := exec("bin/tests")
  if tests_code > 0
  {
    fmt.println("Failed tests")
    os.exit(int(tests_code))
  }
}
