package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"
import "core:sys/linux"

import "./ast"
import "./generation"
import "./generation/x86_64"
import "./program"
import "./type_checking"

help_flags: []string = { "-h", "--help" }
commands: []string = { "build", "health-check", "run" }

main :: proc()
{
  command := len(os.args) > 1 ? os.args[1] : ""
  _, is_valid_command := slice.linear_search(commands, command)
  if !is_valid_command
  {
    _, is_help_flag := slice.linear_search(help_flags, command)
    if !is_help_flag
    {
      fmt.printfln("[bangc] <command> is required to be one of %s.", commands)
      fmt.println("")
    }

    fmt.println("Usage: bangc <command>")
    fmt.println("")
    fmt.println("  The compiler for Bangalang")
    fmt.println("")
    fmt.printfln("    <command>  Possible values include: %s. See 'bangc <command> --help' for more details about the commands.", commands)

    os.exit(is_help_flag ? 0 : 1)
  }

  switch command
  {
  case "build":
    input := len(os.args) > 2 ? os.args[2] : ""
    _, is_help_flag := slice.linear_search(help_flags, input)
    if input == "" || is_help_flag
    {
      if !is_help_flag
      {
        fmt.println("[bangc:build] <input> is required.")
        fmt.println("")
      }

      fmt.println("Usage: bangc build <input>")
      fmt.println("")
      fmt.println("  Build the program with the given entry module.")
      fmt.println("")
      fmt.println("    <input>  The entry module. This is the relative path to the module file excluding the '.bang' extension.")

      os.exit(is_help_flag ? 0 : 1)
    }

    path := fmt.aprintf("%s.bang", input)
    code_data, code_ok := os.read_entire_file(path)
    if !code_ok
    {
      fmt.printfln("Failed to read entry module file '%s'", path)
      os.exit(1)
    }

    build(input, string(code_data), fmt.aprintf("bin/%s", input))
  case "health-check":
    failed_tests := run_test_suite()
    if len(failed_tests) > 0
    {
      fmt.println("Tests failed:")
      for failed_test in failed_tests
      {
        fmt.printfln("  %s", failed_test)
      }
    }

    os.exit(len(failed_tests) > 0 ? 1 : 0)
  case "run":
    input := len(os.args) > 2 ? os.args[2] : ""
    _, is_help_flag := slice.linear_search(help_flags, input)
    if input == "" || is_help_flag
    {
      if !is_help_flag
      {
        fmt.println("[bangc:run] <input> is required.")
        fmt.println("")
      }

      fmt.println("Usage: bangc run <input>")
      fmt.println("")
      fmt.println("  Build and run the program with the given entry module.")
      fmt.println("")
      fmt.println("    <input>  The entry module. This is the relative path to the module file excluding the '.bang' extension.")

      os.exit(is_help_flag ? 0 : 1)
    }

    path := fmt.aprintf("%s.bang", input)
    code_data, code_ok := os.read_entire_file(path)
    if !code_ok
    {
      fmt.printfln("Failed to read entry module file '%s'", path)
      os.exit(1)
    }

    run(input, string(code_data), fmt.aprintf("bin/%s", input))
  case:
    assert(false, "Unsupported command")
  }
}

run :: proc(name: string, code: string, out_path: string)
{
  build(name, code, out_path)

  os.exit(int(exec(out_path)))
}

build :: proc(name: string, code: string, out_path: string)
{
  asm_path := strings.concatenate({ out_path, ".asm" })
  object_path := strings.concatenate({ out_path, ".o" })

  the_program := compile(name, code, asm_path)

  nasm_command := strings.concatenate({ "nasm -f elf64 ", asm_path, " -o ", object_path })
  nasm_code := exec(nasm_command)
  if nasm_code > 0
  {
    fmt.println("Failed to assemble")
    os.exit(int(nasm_code))
  }

  links: string
  for link in the_program.links
  {
    links = strings.concatenate({ links, " -l", link })
  }

  ld_command := strings.concatenate({ "ld -dynamic-linker /lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 ", object_path, " -o ", out_path, links })
  ld_code := exec(ld_command)
  if ld_code > 0
  {
    fmt.println("Failed to link")
    os.exit(int(ld_code))
  }
}

compile :: proc(name: string, code: string, asm_path: string) -> program.program
{
  the_program: program.program
  program.init(&the_program)

  globals_data, globals_ok := os.read_entire_file("stdlib/core/globals.bang")
  if !globals_ok
  {
    fmt.println("Failed to read globals module file")
    os.exit(1)
  }

  globals_path: []string = { "core", "globals" }
  if !type_checking.type_check_program(&the_program, globals_path, string(globals_data))
  {
    os.exit(1)
  }

  globals_module := &the_program.modules[program.get_qualified_module_name(globals_path)]
  for identifier in globals_module.identifiers
  {
    if identifier == "import"
    {
      identifier_node := globals_module.identifiers[identifier]
      append(&identifier_node.data_type.children, ast.make_node({ type = .type, value = "[module]" }))
    }

    the_program.identifiers[identifier] = globals_module.identifiers[identifier]
  }

  path: []string = { "[main]", name }
  if !type_checking.type_check_program(&the_program, path, code)
  {
    os.exit(1)
  }

  gen_ctx: generation.gen_context =
  {
    program = &the_program,
    path = path
  }

  strings.builder_init(&gen_ctx.output)
  x86_64.generate_program(&gen_ctx)

  file, file_error := os.open(asm_path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o666)
  if file_error != nil
  {
    fmt.println("Failed to open asm file")
    os.exit(1)
  }
  defer os.close(file)

  fmt.fprint(file, strings.to_string(gen_ctx.output))

  return the_program
}

exec :: proc(command: string) -> u32
{
  return linux.WEXITSTATUS(u32(libc.system(strings.clone_to_cstring(command))))
}
