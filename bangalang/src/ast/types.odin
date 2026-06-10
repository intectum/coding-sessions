package ast

import "../src"

scope :: struct
{
  path: []string,
  statements: [dynamic]^node,
  references: map[string][dynamic]string,
  identifiers: map[string]^node,
  children: map[string]^scope,
  type_checked: bool, // TODO review

  // TODO move to ctx
  f32_literals: [dynamic]string,
  f64_literals: [dynamic]string,
  string_literals: [dynamic]string,
  cstring_literals: [dynamic]string,
  static_vars: map[string]^node
}

node :: struct
{
  type: node_type,
  value: string,
  data_type: ^node,
  allocator: ^node,
  modifier: ^node,
  children: [dynamic]^node,
  src_position: src.position
}

node_type :: enum
{
  none,
  add,
  add_assign,
  and,
  assign,
  assignment_statement,
  basic_for_statement,
  bitwise_and,
  bitwise_and_assign,
  bitwise_or,
  bitwise_or_assign,
  boolean_literal,
  break_statement,
  char_literal,
  call,
  compound_literal,
  continue_statement,
  default,
  dereference,
  divide,
  divide_assign,
  enum_type,
  equal,
  greater_than,
  greater_than_or_equal,
  group,
  identifier,
  if_statement,
  kernel_type,
  less_than,
  less_than_or_equal,
  module_type,
  modulo,
  modulo_assign,
  multiply,
  multiply_assign,
  negate,
  nil_literal,
  not,
  not_equal,
  number_literal,
  or,
  procedure_type,
  range,
  ranged_for_statement,
  reference,
  return_statement,
  scope_statement,
  string_literal,
  struct_type,
  subscript,
  subtract,
  subtract_assign,
  switch_
}

core_globals_path: []string = { "core", "globals" }

statements: []node_type = { .assignment_statement, .basic_for_statement, .break_statement, .continue_statement, .if_statement, .ranged_for_statement, .return_statement, .scope_statement }
binary_operators: []node_type = { .add, .and, .bitwise_and, .bitwise_or, .divide, .equal, .greater_than, .greater_than_or_equal, .less_than, .less_than_or_equal, .modulo, .multiply, .not_equal, .or, .subtract }
comparison_operators: []node_type = { .equal, .greater_than, .greater_than_or_equal, .less_than, .less_than_or_equal, .not_equal }
literals: []node_type = { .boolean_literal, .compound_literal, .nil_literal, .number_literal, .string_literal }
complex_types: []node_type = { .enum_type, .module_type, .kernel_type, .procedure_type, .struct_type }

simple_types: []string = { "[any_float]", "[any_number]", "[any_string]", "[none]", "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64", "bool", "cint", "cuint", "f32", "f64", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64" }
numerical_types: []string = { "[any_float]", "[any_number]", "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64", "cint", "cuint", "f32", "f64", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64" }
float_types: []string = { "[any_float]", "f32", "f64" }
integer_types: []string = { "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64", "cint", "cuint", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64" }
atomic_integer_types: []string = { "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64" }
signed_integer_types: []string = { "cint", "i8", "i16", "i32", "i64" }
unsigned_integer_types: []string = { "cuint", "u8", "u16", "u32", "u64" }
