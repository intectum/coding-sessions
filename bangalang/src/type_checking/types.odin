package type_checking

import "core:slice"
import "core:strings"

import "../ast"
import "../src"

numerical_types: []string = { "[any_float]", "[any_int]", "[any_number]", "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64", "cint", "cuint", "f32", "f64", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64" }
float_types: []string = { "[any_float]", "f32", "f64" }
integer_types: []string = { "[any_int]", "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64", "cint", "cuint", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64" }
atomic_integer_types: []string = { "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64" }
signed_integer_types: []string = { "cint", "i8", "i16", "i32", "i64" }
unsigned_integer_types: []string = { "cuint", "u8", "u16", "u32", "u64" }

coerce_type :: proc(a: ^ast.node, b: ^ast.node) -> (^ast.node, bool)
{
  if a == nil || a.value == "[none]" || a.directive == "#untyped"
  {
    return b, true
  }

  if b == nil || b.value == "[none]" || b.directive == "#untyped"
  {
    return a, true
  }

  if a.type != b.type
  {
    return nil, false
  }

  compatible_value_types := false

  if a.value != b.value
  {
    if a.type == .type
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

      a_string := a.value == "[slice]" && a.children[0].value == "u8"
      a_cstring := a.value == "cstring"
      if b.value == "[any_string]" && !a_string && !a_cstring
      {
        return nil, false
      }

      b_string := b.value == "[slice]" && b.children[0].value == "u8"
      b_cstring := b.value == "cstring"
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
    else
    {
      return nil, false
    }
  }

  if !compatible_value_types
  {
    if len(a.children) != len(b.children)
    {
      return nil, false
    }

    for child_index := 0; child_index < len(a.children); child_index += 1
    {
      _, child_coerce_ok := coerce_type(&a.children[child_index], &b.children[child_index])
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

type_name :: proc(type_node: ^ast.node) -> string
{
  assert(type_node.type == .reference || type_node.type == .type, "Invalid type")

  prefix := type_node.directive != "" ? strings.concatenate({ type_node.directive, " " }) : ""

  if type_node.type == .reference
  {
    return strings.concatenate({ prefix, "^", type_name(&type_node.children[0]) })
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
  case "[array]":
    return strings.concatenate({ prefix, type_name(&type_node.children[0]), "[", type_node.children[1].value, "]" })
  case "[procedure]":
    param_type_names: [dynamic]string
    params_type_node := type_node.children[0]
    for &param_node in params_type_node.children
    {
      append(&param_type_names, strings.concatenate({ param_node.value, ": ", type_name(ast.get_type(&param_node)) }))
    }

    return_type_name: string
    if len(type_node.children) == 2
    {
      return_type_node := &type_node.children[1]
      return_type_name = strings.concatenate({ " -> ", type_name(return_type_node) })
    }

    return strings.concatenate({ prefix, "proc(", strings.join(param_type_names[:], ", "), ")", return_type_name })
  case "[slice]":
    return strings.concatenate({ prefix, type_name(&type_node.children[0]), "[]" })
  case "[struct]":
    member_type_names: [dynamic]string
    for &member_node in type_node.children
    {
      append(&member_type_names, strings.concatenate({ member_node.value, ": ", type_name(ast.get_type(&member_node)) }))
    }

    return strings.concatenate({ prefix, "struct { ", strings.join(member_type_names[:], ", "), " }" })
  }

  return strings.concatenate({ prefix, type_node.value })
}

upgrade_types :: proc(node: ^ast.node, new_type_node: ^ast.node, ctx: ^type_checking_context)
{
  if node.type == .type
  {
    if new_type_node.value == "[any_string]" && node.value == "[any_string]"
    {
      node^ = ctx.program.identifiers["string"]
    }
    else if node.value == "[none]" || node.value == "[any_float]" || node.value == "[any_int]" || node.value == "[any_number]" || node.value == "[any_string]" || node.directive == "#untyped"
    {
      node^ = new_type_node^
    }
  }

  for &child_node in node.children
  {
    upgrade_types(&child_node, new_type_node, ctx)
  }
}

resolve_types :: proc(node: ^ast.node, ctx: ^type_checking_context) -> bool
{
  if node.type == .identifier || node.type == .type
  {
    if len(node.children) > 0 && (node.children[0].type == .identifier || node.children[0].type == .type)
    {
      child_node := &node.children[0]
      module := &ctx.program.modules[ctx.path[0]]
      if child_node.value in module.imports
      {
        imported_module := &ctx.program.modules[module.imports[child_node.value]]
        if node.value in imported_module.identifiers
        {
          identifier_node := &imported_module.identifiers[node.value]
          if ast.is_type(identifier_node)
          {
            node^ = identifier_node^
            return true
          }
        }
      }
    }
    else
    {
      identifier_node, _ := get_identifier_node(ctx, node.value)
      if identifier_node != nil && ast.is_type(identifier_node)
      {
        node^ = identifier_node^
        return true
      }
    }
  }

  if node.type == .type && node.value[0] != '['
  {
    src.print_position_message(node.src_position, "Type '%s' was not found", node.value)
    return false
  }

  for &child_node in node.children
  {
    if child_node.type != .scope && resolve_types(&child_node, ctx)
    {
      if node.type == .index
      {
        node.type = .type
        node.value = len(node.children) == 1 ? "[slice]" : "[array]"
      }
    }
  }

  return false
}
