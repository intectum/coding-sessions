package ast

import "core:fmt"
import "core:slice"
import "core:strings"

import "../src"
import "../tokens"

init_root :: proc(root: ^scope)
{
  root.identifiers["atomic_i8"] = make_node({ type = .identifier, value = "atomic_i8" })
  root.identifiers["atomic_i16"] = make_node({ type = .identifier, value = "atomic_i16" })
  root.identifiers["atomic_i32"] = make_node({ type = .identifier, value = "atomic_i32" })
  root.identifiers["atomic_i64"] = make_node({ type = .identifier, value = "atomic_i64" })
  root.identifiers["bool"] = make_node({ type = .identifier, value = "bool" })
  root.identifiers["cint"] = make_node({ type = .identifier, value = "cint" })
  root.identifiers["cuint"] = make_node({ type = .identifier, value = "cuint" })
  root.identifiers["f32"] = make_node({ type = .identifier, value = "f32" })
  root.identifiers["f64"] = make_node({ type = .identifier, value = "f64" })
  root.identifiers["i8"] = make_node({ type = .identifier, value = "i8" })
  root.identifiers["i16"] = make_node({ type = .identifier, value = "i16" })
  root.identifiers["i32"] = make_node({ type = .identifier, value = "i32" })
  root.identifiers["i64"] = make_node({ type = .identifier, value = "i64" })
  root.identifiers["u8"] = make_node({ type = .identifier, value = "u8" })
  root.identifiers["u16"] = make_node({ type = .identifier, value = "u16" })
  root.identifiers["u32"] = make_node({ type = .identifier, value = "u32" })
  root.identifiers["u64"] = make_node({ type = .identifier, value = "u64" })

  allocator_type := make_node({ type = .procedure_type, value = "proc" })
  append(&allocator_type.children, make_node({ type = .group, value = "[parameters]" }))

  string_type := make_node({ type = .subscript })
  append(&string_type.children, root.identifiers["u8"])
  range_node := make_node({ type = .range })
  append(&range_node.children, make_node({ type = .nil_literal }))
  append(&range_node.children, make_node({ type = .nil_literal }))
  append(&string_type.children, range_node)

  code_allocator_type := clone_node(allocator_type)
  append(&code_allocator_type.children[0].children, make_node({ type = .assignment_statement }))
  append(&code_allocator_type.children[0].children[0].children, make_node({ type = .identifier, value = "src", data_type = string_type }))
  append(&code_allocator_type.children, string_type)
  root.identifiers["code_allocator"] = code_allocator_type

  memory_allocator_type := clone_node(allocator_type)
  append(&memory_allocator_type.children[0].children, make_node({ type = .assignment_statement }))
  append(&memory_allocator_type.children[0].children[0].children, make_node({ type = .identifier, value = "size", data_type = root.identifiers["u64"] }))
  append(&memory_allocator_type.children, make_node({ type = .reference }))
  append(&memory_allocator_type.children[1].children, root.identifiers["u8"])
  root.identifiers["memory_allocator"] = memory_allocator_type

  nil_allocator_type := clone_node(allocator_type)
  root.identifiers["nil_allocator"] = nil_allocator_type

  static_allocator_type := clone_node(allocator_type)
  append(&static_allocator_type.children, root.identifiers["u64"])
  root.identifiers["static_allocator"] = static_allocator_type

  root.identifiers["code"] = make_node({ type = .identifier, value = "code", data_type = code_allocator_type })
  root.identifiers["extern"] = make_node({ type = .identifier, value = "extern", data_type = nil_allocator_type })
  root.identifiers["none"] = make_node({ type = .identifier, value = "none", data_type = nil_allocator_type })
  root.identifiers["stack"] = make_node({ type = .identifier, value = "stack", data_type = static_allocator_type })
  root.identifiers["static"] = make_node({ type = .identifier, value = "static", data_type = static_allocator_type })
}

get_qualified_name :: proc(path: []string) -> string
{
  qualified_name := get_qualified_module_name(path)

  if len(path) == 1
  {
    qualified_name = strings.concatenate({ qualified_name, ".", path[0] })
  }
  else if len(path) > 2
  {
    qualified_name = strings.concatenate({ qualified_name, ".", strings.join(path[2:], ".") })
  }

  return qualified_name
}

get_qualified_module_name :: proc(path: []string) -> string
{
  if len(path) == 1 do return "core.$lib.globals.$module"

  final_module_name, _ := strings.replace_all(path[1], "/", ".")
  qualified_module_name := strings.concatenate({ final_module_name, ".$module" })

  if path[0] == "[main]"
  {
    return qualified_module_name
  }

  final_lib_name, _ := strings.replace_all(path[0], "/", ".")
  return strings.concatenate({ final_lib_name, ".$lib.", qualified_module_name })
}

get_scope :: proc(root: ^scope, path: []string) -> ^scope
{
  current := root
  for fragment in path
  {
    if !(fragment in current.children) do return nil
    current = current.children[fragment]
  }

  return current
}

make_node :: proc(init: node = {}) -> ^node
{
  new_node := new(node)
  new_node^ = init
  return new_node
}

clone_node :: proc(root: ^node) -> ^node
{
  clone := make_node(root^)

  if root.data_type != nil
  {
    clone.data_type = clone_node(root.data_type)
  }

  clone.children = {}
  for child in root.children
  {
    append(&clone.children, clone_node(child))
  }

  return clone
}

print_node :: proc(output: ^strings.Builder, root: ^node, indentations: int)
{
  print_indentations(output, indentations)
  fmt.sbprintln(output, "{")
  print_indentations(output, indentations)
  fmt.sbprintf(output, "  \"type\": \"%s\"", root.type)
  if root.value != ""
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    if root.type == .string_literal
    {
      fmt.sbprintf(output, "  \"value\": %s", root.value)
    }
    else
    {
      fmt.sbprintf(output, "  \"value\": \"%s\"", root.value)
    }
  }
  if root.data_type != nil
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    fmt.sbprintln(output, "  \"data_type\":")
    print_node(output, root.data_type, indentations + 1)
  }
  if root.allocator != nil
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    fmt.sbprintln(output, "  \"allocator\":")
    print_node(output, root.allocator, indentations + 1)
  }
  if root.directive != ""
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    fmt.sbprintf(output, "  \"valdirectiveue\": \"%s\"", root.directive)
  }
  if len(root.children) > 0
  {
    fmt.sbprintln(output, ",")
    print_indentations(output, indentations)
    fmt.sbprintln(output, "  \"children\":")
    print_indentations(output, indentations)
    fmt.sbprintln(output, "  [")
    for child, index in root.children
    {
      if index > 0
      {
        fmt.sbprintln(output, ",")
      }
      print_node(output, child, indentations + 2)
    }
    fmt.sbprintln(output, "")
    print_indentations(output, indentations)
    fmt.sbprint(output, "  ]")
  }
  fmt.sbprintln(output, "")
  print_indentations(output, indentations)
  fmt.sbprint(output, "}")
}

print_indentations :: proc(output: ^strings.Builder, indentations: int)
{
  for index in 0..<indentations
  {
    fmt.sbprint(output, "  ")
  }
}

is_import_statement :: proc(statement: ^node) -> bool
{
  if statement.type == .assignment_statement && len(statement.children) > 1
  {
    rhs_node := statement.children[2]
    return rhs_node.type == .call && rhs_node.children[0].value == "import"
  }

  return false
}

// TODO remove?
is_type_alias_statement :: proc(statement: ^node) -> bool
{
  return statement.type == .assignment_statement && len(statement.children) > 1 && is_type(statement.children[2])
}

is_member :: proc(identifier: ^node) -> bool
{
  if identifier.type != .identifier || len(identifier.children) == 0
  {
    return false
  }

  final_identifier := identifier
  for final_identifier.children[0].type == .dereference || final_identifier.children[0].type == .reference || final_identifier.children[0].type == .subscript
  {
    final_identifier = final_identifier.children[0]
  }

  return final_identifier.children[0].type == .identifier || is_type(final_identifier.children[0])
}

is_type :: proc(type: ^node) -> bool
{
  if type.type == .reference || type.type == .subscript
  {
    return is_type(type.children[0])
  }

  if slice.contains(complex_types, type.type)
  {
    return true
  }

  if type.type == .identifier && slice.contains(simple_types, type.value)
  {
    return true
  }

  return false
}

is_placeholder :: proc(node: ^node) -> bool
{
  return strings.has_prefix(node.value, "$")
}

is_array :: proc(type: ^node) -> bool
{
  return type.type == .subscript && type.children[1].type != .range && is_type(type)
}

is_slice :: proc(type: ^node) -> bool
{
  return type.type == .subscript && type.children[1].type == .range && is_type(type)
}

to_node :: proc(token: tokens.token) -> ^node
{
  return make_node({
    type = to_node_type(token.type),
    value = token.value,
    src_position = token.src_position
  })
}

to_node_type :: proc(token_type: tokens.token_type) -> node_type
{
  #partial switch token_type
  {
  case .ampersand:
    return .bitwise_and
  case .ampersand_equals:
    return .bitwise_and_assign
  case .ampersand_ampersand:
    return .and
  case .asterisk:
    return .multiply
  case .asterisk_equals:
    return .multiply_assign
  case .backslash:
    return .divide
  case .backslash_equals:
    return .divide_assign
  case .closing_angle_bracket:
    return .greater_than
  case .closing_angle_bracket_equals:
    return .greater_than_or_equal
  case .equals:
    return .assign
  case .equals_equals:
    return .equal
  case .exclamation_equals:
    return .not_equal
  case .identifier:
    return .identifier
  case .minus:
    return .subtract
  case .minus_equals:
    return .subtract_assign
  case .opening_angle_bracket:
    return .less_than
  case .opening_angle_bracket_equals:
    return .less_than_or_equal
  case .percent:
    return .modulo
  case .percent_equals:
    return .modulo_assign
  case .pipe:
    return .bitwise_or
  case .pipe_equals:
    return .bitwise_or_assign
  case .pipe_pipe:
    return .or
  case .placeholder:
    return .identifier
  case .plus:
    return .add
  case .plus_equals:
    return .add_assign
  }

  assert(false, "Unsupported node type")
  return .none
}

get_declaration :: proc(root: ^scope, scope: ^scope, identifier: ^node) -> (^node, []string)
{
  if is_member(identifier) && identifier.children[0].data_type != nil && identifier.children[0].data_type.type == .module_type
  {
    child_node := identifier.children[0]

    module := get_scope(root, scope.path[:2])
    if !(child_node.value in module.references) do return nil, {}

    imported_module_path := &module.references[child_node.value]
    if len(imported_module_path) != 2 do return nil, {}

    imported_module := get_scope(root, imported_module_path[:])
    if !(identifier.value in imported_module.identifiers) do return nil, {}

    identifier_node := imported_module.identifiers[identifier.value]
    if identifier_node.directive == "#private" do return nil, {}

    return identifier_node, imported_module_path[:]
  }

  if identifier.value in scope.identifiers
  {
    return scope.identifiers[identifier.value], scope.path
  }

  for path_length := len(scope.path); path_length >= 0; path_length -= 1
  {
    path := scope.path[:path_length]
    current := get_scope(root, path)

    if identifier.value in current.identifiers
    {
      identifier_node := current.identifiers[identifier.value]
      if path_length == len(scope.path) || is_visible_in_nested_proc(root, identifier_node)
      {
        return identifier_node, path
      }
    }
  }

  return nil, {}
}

is_visible_in_nested_proc :: proc(root: ^scope, declaration: ^node) -> bool
{
  if is_type(declaration) || declaration.data_type.type == .module_type
  {
    return true
  }

  // Should only be core allocators that do not have an allocator themselves...
  if declaration.allocator == nil do return false

  _, memory_allocator := coerce_type(declaration.allocator.data_type, root.identifiers["memory_allocator"])
  return !memory_allocator && declaration.allocator != root.identifiers["stack"]
}

coerce_type :: proc(a: ^node, b: ^node) -> (^node, bool)
{
  if a == nil || a.value == "[none]" || is_placeholder(a)
  {
    return b, true
  }

  if b == nil || b.value == "[none]" || is_placeholder(b)
  {
    return a, true
  }

  compatible_value_types := false

  if a.value != b.value
  {
    _, a_numerical_type := slice.linear_search(numerical_types, a.value)
    if b.value == "[any_number]" && !a_numerical_type
    {
      return nil, false
    }

    _, b_numerical_type := slice.linear_search(numerical_types, b.value)
    if a.value == "[any_number]" && !b_numerical_type
    {
      return nil, false
    }

    if a.value != "[any_number]" && b.value != "[any_number]"
    {
      _, a_float_type := slice.linear_search(float_types, a.value)
      if b.value == "[any_float]" && !a_float_type
      {
        return nil, false
      }

      _, b_float_type := slice.linear_search(float_types, b.value)
      if a.value == "[any_float]" && !b_float_type
      {
        return nil, false
      }

      _, a_integer_type := slice.linear_search(integer_types, a.value)
      if b.value == "[any_int]" && !a_integer_type
      {
        return nil, false
      }

      _, b_integer_type := slice.linear_search(integer_types, b.value)
      if a.value == "[any_int]" && !b_integer_type
      {
        return nil, false
      }
    }

    a_string := is_slice(a) && a.children[0].value == "u8"
    a_cstring := a.type == .reference && a.children[0].value == "u8"
    if b.value == "[any_string]" && !a_string && !a_cstring
    {
      return nil, false
    }

    b_string := is_slice(b) && b.children[0].value == "u8"
    b_cstring := b.type == .reference && b.children[0].value == "u8"
    if a.value == "[any_string]" && !b_string && !b_cstring
    {
      return nil, false
    }

    if a.value != "[any_number]" && b.value != "[any_number]" &&
    a.value != "[any_float]" && b.value != "[any_float]" &&
    a.value != "[any_int]" && b.value != "[any_int]" &&
    a.value != "[any_string]" && b.value != "[any_string]"
    {
      return nil, false
    }

    compatible_value_types = true
  }

  if !compatible_value_types
  {
    if a.type != b.type
    {
      return nil, false
    }

    if len(a.children) != len(b.children)
    {
      return nil, false
    }

    for child_index := 0; child_index < len(a.children); child_index += 1
    {
      _, child_coerce_ok := coerce_type(a.children[child_index], b.children[child_index])
      if !child_coerce_ok
      {
        return nil, false
      }
    }
  }

  if a.value == "[any_number]"
  {
    return b, true
  }
  else if b.value == "[any_number]"
  {
    return a, true
  }

  return a.value == "[any_float]" || a.value == "[any_int]" || a.value == "[any_string]" ? b : a, true
}

type_name :: proc(type_node: ^node) -> string
{
  assert(is_type(type_node), "Invalid type")

  prefix := type_node.directive != "" ? strings.concatenate({ type_node.directive, " " }) : ""

  #partial switch type_node.type
  {
  case .enum_type:
    member_type_names: [dynamic]string
    for member_node in type_node.children
    {
      append(&member_type_names, member_node.value)
    }

    return strings.concatenate({ prefix, "enum {{ ", strings.join(member_type_names[:], ", "), " }}" })
  case .kernel_type, .procedure_type:
    param_type_names: [dynamic]string
    params_type_node := type_node.children[0]
    for param_node in params_type_node.children
    {
      param_lhs_node := param_node.children[0]
      append(&param_type_names, strings.concatenate({ param_lhs_node.value, ": ", type_name(param_lhs_node.data_type) }))
    }

    return_type_name: string
    if len(type_node.children) == 2
    {
      return_type_node := type_node.children[1]
      return_type_name = strings.concatenate({ " -> ", type_name(return_type_node) })
    }

    return strings.concatenate({ prefix, type_node.value, "(", strings.join(param_type_names[:], ", "), ")", return_type_name })
  case .reference:
    return strings.concatenate({ prefix, "^", type_name(type_node.children[0]) })
  case .struct_type:
    member_type_names: [dynamic]string
    for member_node in type_node.children
    {
      append(&member_type_names, strings.concatenate({ member_node.value, ": ", type_name(member_node.data_type) }))
    }

    return strings.concatenate({ prefix, "struct {{ ", strings.join(member_type_names[:], ", "), " }}" })
  case .subscript:
    if is_array(type_node)
    {
      length_expression_node := type_node.children[1]
      length := length_expression_node.type == .number_literal ? length_expression_node.value : "?"
      return strings.concatenate({ prefix, type_name(type_node.children[0]), "[", length, "]" })
    }
    else
    {
      return strings.concatenate({ prefix, type_name(type_node.children[0]), "[]" })
    }
  }

  switch type_node.value
  {
  case "[any_float]":
    return strings.concatenate({ prefix, "<any float>" })
  case "[any_int]":
    return strings.concatenate({ prefix, "<any int>" })
  case "[any_number]":
    return strings.concatenate({ prefix, "<any number>" })
  case "[any_string]":
    return strings.concatenate({ prefix, "<any string>" })
  }

  return strings.concatenate({ prefix, type_node.value })
}

type_var_name :: proc(type_node: ^node) -> string
{
  assert(is_type(type_node), "Invalid type")

  prefix := type_node.directive != "" ? strings.concatenate({ type_node.directive, "." }) : ""

  #partial switch type_node.type
  {
  case .enum_type:
    member_type_names: [dynamic]string
    for member_node in type_node.children
    {
      append(&member_type_names, member_node.value)
    }

    return strings.concatenate({ prefix, "$enum.", strings.join(member_type_names[:], ".") })
  case .kernel_type, .procedure_type:
    param_type_names: [dynamic]string
    params_type_node := type_node.children[0]
    for param_node in params_type_node.children
    {
      param_lhs_node := param_node.children[0]
      append(&param_type_names, strings.concatenate({ param_lhs_node.value, ".", type_var_name(param_lhs_node.data_type) }))
    }

    return_type_name: string
    if len(type_node.children) == 2
    {
      return_type_node := type_node.children[1]
      return_type_name = strings.concatenate({ ".$return.", type_var_name(return_type_node) })
    }

    return strings.concatenate({ prefix, "$", type_node.value, ".", strings.join(param_type_names[:], "."), return_type_name })
  case .reference:
    return strings.concatenate({ prefix, "$ref.", type_var_name(type_node.children[0]) })
  case .struct_type:
    member_type_names: [dynamic]string
    for member_node in type_node.children
    {
      append(&member_type_names, strings.concatenate({ member_node.value, ".", type_var_name(member_node.data_type) }))
    }

    return strings.concatenate({ prefix, "$struct.", strings.join(member_type_names[:], ".") })
  case .subscript:
    if is_array(type_node)
    {
      length_expression_node := type_node.children[1]
      length := length_expression_node.value
      return strings.concatenate({ prefix, "$array.", type_var_name(type_node.children[0]), ".", length })
    }
    else
    {
      return strings.concatenate({ prefix, "$slice.", type_var_name(type_node.children[0]) })
    }
  }

  return strings.concatenate({ prefix, type_node.value })
}

upgrade_types :: proc(root: ^scope, current_node: ^node, new_type_node: ^node) -> bool
{
  if current_node.data_type != nil
  {
    if new_type_node.value == "[any_string]" && current_node.data_type.value == "[any_string]"
    {
      current_node.data_type = root.identifiers["string"]
    }
    else if current_node.data_type.value == "[any_int]" || current_node.data_type.value == "[any_number]"
    {
      if current_node.type == .number_literal && strings.has_prefix(current_node.value, "-")
      {
        _, unsigned_integer_type := slice.linear_search(unsigned_integer_types, new_type_node.value)
        if unsigned_integer_type
        {
          src.print_position_message(current_node.src_position, "cannot upgrade negative integer literal '%s' to type '%s'", current_node.value, type_name(new_type_node))
          return false
        }
      }

      current_node.data_type = new_type_node
    }
    else if current_node.data_type.value == "[none]" || current_node.data_type.value == "[any_float]" || current_node.data_type.value == "[any_string]"
    {
      current_node.data_type = new_type_node
    }
  }

  for child_node in current_node.children
  {
    upgrade_types(root, child_node, new_type_node) or_return
  }

  return true
}
