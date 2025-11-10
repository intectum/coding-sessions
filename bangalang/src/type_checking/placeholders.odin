package type_checking

import "core:strings"

import "../ast"

is_placeholder :: proc(node: ^ast.node) -> bool
{
  return strings.has_prefix(node.value, "$")
}

has_placeholders :: proc(node: ^ast.node) -> bool
{
  if is_placeholder(node) do return true

  if node.data_type != nil
  {
    if has_placeholders(node.data_type) do return true
  }

  for child in node.children
  {
    if has_placeholders(child) do return true
  }

  return false
}

resolve_placeholders :: proc(generic: ^ast.node, concrete: ^ast.node, identifiers: ^map[string]^ast.node) -> bool
{
  found_placeholder := false

  if generic.type == .type && is_placeholder(generic)
  {
    if !(generic.value in identifiers)
    {
      identifiers[generic.value] = concrete
      return true
    }
  }

  if generic.data_type != nil
  {
    if resolve_placeholders(generic.data_type, concrete.data_type, identifiers)
    {
      found_placeholder = true
    }
  }

  for _, index in generic.children
  {
    if resolve_placeholders(generic.children[index], concrete.children[index], identifiers)
    {
      found_placeholder = true
    }
  }

  return found_placeholder
}

