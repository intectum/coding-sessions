package main

import "core:c/libc"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:slice"
import "core:strings"
import "core:sys/linux"

import "./ast"
import "./generation"
import "./generation/json"
import "./generation/kernels"
import "./generation/x86_64"
import "./loading"
import "./type_checking"

commands: []string = { "build", "health-check", "run" }
commands_with_input: []string = { "build", "run" }
targets: []string = { "json", "kernels", "x86_64" }
default_target := "x86_64"

main :: proc()
{
  command_options: map[string][]string
  command_options["build"] = { "help", "intermediaries", "out", "target" }
  command_options["health-check"] = {}
  command_options["run"] = { "help", "intermediaries", "out" }

  command: string
  input: string

  options: map[string]string

  for arg in os.args[1:]
  {
    if command == ""
    {
      if slice.contains([]string { "-h", "--help" }, command)
      {
        fmt.println("Usage: bangc <command>")
        fmt.println("")
        fmt.printfln("  <command>  Possible values include: %s. See 'bangc <command> --help' for more details about the commands.", commands)
        os.exit(0)
      }

      command = arg
    }
    else if input == "" && slice.contains(commands_with_input, command)
    {
      if strings.has_prefix(arg, "-")
      {
        fmt.printfln("[bangc] Invalid input '%s'", arg)
        os.exit(1)
      }

      input = arg
    }
    else if strings.has_prefix(arg, "-")
    {
      split_arg := strings.split(arg, "=")

      switch split_arg[0]
      {
      case "-h", "--help": options["help"] = "true"
      case "--intermediaries": options["intermediaries"] = "true"
      case "-o", "--out": options["out"] = split_arg[1]
      case "-t", "--target": options["target"] = split_arg[1]
      case:
        fmt.printfln("[bangc] Invalid argument '%s'", arg)
        os.exit(1)
      }
    }
    else
    {
      fmt.printfln("[bangc] Invalid argument '%s'", arg)
      os.exit(1)
    }
  }

  if !slice.contains(commands, command)
  {
    fmt.printfln("[bangc] <command> is required to be one of %s.", commands)
    os.exit(1)
  }

  if input == "" && slice.contains(commands_with_input, command)
  {
    fmt.printfln("[bangc:%s] <input> is required.", command)
    os.exit(1)
  }

  for option in options
  {
    if !slice.contains(command_options[command], option)
    {
      fmt.printfln("[bangc:%s] Invalid option '%s'", command, option)
      os.exit(1)
    }
  }

  if slice.contains(command_options[command], "target")
  {
    if !("target" in options)
    {
      options["target"] = default_target
    }

    if !slice.contains(targets, options["target"])
    {
      fmt.printfln("[bangc:%s] <target> is required to be one of %s.", command, targets)
      os.exit(1)
    }
  }

  if slice.contains(command_options[command], "out")
  {
    if !("out" in options)
    {
      options["out"] = input
    }
  }

  switch command
  {
  case "build":
    if options["help"] == "true"
    {
      fmt.println("Build the program with the given entry module.")
      fmt.println("")
      fmt.println("Usage: bangc build <input> [options]")
      fmt.println("")
      fmt.println("  <input>  The entry module. This is the relative path to the module file excluding the '.bang' extension.")
      fmt.println("")
      fmt.println("Options:")
      fmt.println("")
      fmt.printfln("  --intermediaries  Retain intermediate build files.")
      fmt.printfln("  --target,-t  The target to compile to. Possible values include: %s.", targets)
      os.exit(0)
    }

    path := fmt.aprintf("%s.bang", input)
    code_data, code_ok := os.read_entire_file(path)
    if !code_ok
    {
      fmt.printfln("Failed to read entry module file '%s'", path)
      os.exit(1)
    }

    build(input, string(code_data), options["out"], options["target"], options["intermediaries"] == "true")
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
    if options["help"] == "true"
    {
      fmt.println("Build and run the program with the given entry module.")
      fmt.println("")
      fmt.println("Usage: bangc run <input>")
      fmt.println("")
      fmt.println("  <input>  The entry module. This is the relative path to the module file excluding the '.bang' extension.")
      fmt.println("")
      fmt.println("Options:")
      fmt.println("")
      fmt.printfln("  --intermediaries  Retain intermediate build files.")
      os.exit(0)
    }

    path := fmt.aprintf("%s.bang", input)
    code_data, code_ok := os.read_entire_file(path)
    if !code_ok
    {
      fmt.printfln("Failed to read entry module file '%s'", path)
      os.exit(1)
    }

    run(input, string(code_data), options["out"], options["intermediaries"] == "true")
  case:
    assert(false, "Unsupported command")
  }
}

run :: proc(name: string, code: string, out_path: string, intermediaries: bool)
{
  build(name, code, out_path, default_target, intermediaries)

  os.exit(int(exec(out_path)))
}

build :: proc(name: string, code: string, out_path: string, target: string, intermediaries: bool)
{
  os.make_directory(filepath.dir(out_path))

  switch target
  {
  case "json":
    json_path := strings.concatenate({ out_path, ".json" })
    compile(name, code, json_path, target)
  case "kernels":
    compile(name, code, out_path, target)
  case "x86_64":
    asm_path := strings.concatenate({ out_path, ".asm" })
    program := compile(name, code, asm_path, target)
    defer if !intermediaries do os.remove(asm_path)

    object_path := strings.concatenate({ out_path, ".o" })
    nasm_command := strings.concatenate({ "nasm -f elf64 ", asm_path, " -o ", object_path })
    defer if !intermediaries do os.remove(object_path)
    nasm_code := exec(nasm_command)
    if nasm_code > 0
    {
      fmt.println("Failed to assemble")
      os.exit(int(nasm_code))
    }

    links: string
    for link in program.references
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
  case:
    assert(false, "Unsupported target")
  }
}

compile :: proc(name: string, code: string, out_path: string, target: string) -> ast.scope
{
  program: ast.scope
  ast.init_root(&program)

  globals_data, globals_ok := os.read_entire_file(fmt.aprintf("%s/stdlib/core/globals.bang", filepath.dir(os.args[0])))
  if !globals_ok
  {
    fmt.println("Failed to read globals module file")
    os.exit(1)
  }

  if !loading.load_module(&program, ast.core_globals_path, string(globals_data))
  {
    os.exit(1)
  }

  type_checking_ctx: type_checking.type_checking_context =
  {
    program = &program,
    scope = ast.get_scope(&program, ast.core_globals_path)
  }

  if !type_checking.type_check_statements(&type_checking_ctx, type_checking_ctx.scope.statements[:])
  {
    os.exit(1)
  }

  for identifier in type_checking_ctx.scope.identifiers
  {
    if identifier == "import"
    {
      import_declaration := type_checking_ctx.scope.identifiers[identifier]
      append(&import_declaration.data_type.children, ast.make_node({ type = .module_type }))
    }

    program.identifiers[identifier] = type_checking_ctx.scope.identifiers[identifier]
  }

  path: []string = { "[main]", name }
  if !loading.load_module(&program, path, code)
  {
    os.exit(1)
  }

  type_checking_ctx.scope = ast.get_scope(&program, path)
  type_checking_ctx.within_entry_module = true

  call_main, call_main_ok := loading.load_code(name, "main()")
  if !call_main_ok
  {
    fmt.println("Failed to load call to main")
    os.exit(1)
  }

  append(&type_checking_ctx.scope.statements, call_main[0])

  if !type_checking.type_check_statements(&type_checking_ctx, type_checking_ctx.scope.statements[:])
  {
    os.exit(1)
  }

  if !type_checking.type_check_queue(&program)
  {
    os.exit(1)
  }

  import_path: [dynamic]string
  defer delete(import_path)

  if !type_checking.type_check_cyclic_imports(&program, path, &import_path)
  {
    os.exit(1)
  }

  gen_ctx: generation.gen_context =
  {
    program = &program,
    scope = ast.get_scope(&program, path)
  }

  strings.builder_init(&gen_ctx.output)
  defer strings.builder_destroy(&gen_ctx.output)

  switch target
  {
  case "json":
    json.generate_program(&gen_ctx)
  case "kernels":
    kernels.generate_program(&gen_ctx)
  case "x86_64":

    x86_64.generate_program(&gen_ctx)
  case:
    assert(false, "Unsupported target")
  }

  if target != "kernels"
  {
    file, file_error := os.open(out_path, os.O_CREATE | os.O_WRONLY | os.O_TRUNC, 0o666)
    if file_error != nil
    {
      fmt.println("Failed to open out file")
      os.exit(1)
    }
    defer os.close(file)

    fmt.fprint(file, strings.to_string(gen_ctx.output))
  }

  return program
}

exec :: proc(command: string) -> u32
{
  return linux.WEXITSTATUS(u32(libc.system(strings.clone_to_cstring(command))))
}
