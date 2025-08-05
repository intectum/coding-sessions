package generation

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

import "../ast"

index_type_node := ast.node { type = .type, value = "i64" }
unknown_reference_type_node: ast.node = { type = .reference }

contains_allocations :: proc(node: ^ast.node) -> bool
{
  if node.type == .compound_literal
  {
    return true
  }

  if node.type == .index && ast.get_type(node).value != "[slice]"
  {
    return true
  }

  if node.type == .call && ast.get_type(&node.children[0]).directive != "#extern"
  {
    return true
  }

  for &child_node in node.children
  {
    if contains_allocations(&child_node)
    {
      return true
    }
  }

  return false
}

get_raw_location :: proc(file: os.Handle, container_type_node: ^ast.node, container_location: location, register_num: int) -> location
{
  switch container_type_node.value
  {
  case "[array]":
    location := register(register_num, &unknown_reference_type_node)
    fmt.fprintfln(file, "  lea %s, %s ; reference", to_operand(location), to_operand(container_location))
    return location
  case "[slice]":
    return container_location
  }

  assert(false, "Unsupported raw location")
  return {}
}

get_length_location :: proc(container_type_node: ^ast.node, container_location: location) -> location
{
  switch container_type_node.value
  {
  case "[array]":
    return immediate(container_type_node.children[1].value)
  case "[slice]":
    length_location := container_location
    length_location.offset += address_size
    return length_location
  }

  assert(false, "Unsupported length location")
  return immediate(1)
}

get_data_section_name :: proc(data_section_values: ^[dynamic]string, prefix: string, value: string) -> string
{
  index := len(data_section_values)
  for existing_value, existing_index in data_section_values
  {
    if existing_value == value
    {
      index = existing_index
      break
    }
  }

  if index == len(data_section_values)
  {
    append(data_section_values, value)
  }

  buf: [8]byte
  return strings.concatenate({ prefix, strconv.itoa(buf[:], index) })
}

nilify :: proc(file: os.Handle, location: location, type_node: ^ast.node)
{
  assert(location.type == .memory, "Cannot nilify a non-memory location")

  fmt.fprintfln(file, "  lea rdi, %s ; nil: dest", to_operand(location))
  fmt.fprintfln(file, "  mov rcx, %i ; nil: count", to_byte_size(type_node))
  fmt.fprintln(file, "  mov rax, 0 ; nil: value")
  fmt.fprintln(file, "  rep stosb ; nil")
}
