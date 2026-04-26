package ast

import "../src"

node :: struct
{
  type: node_type,
  value: string,
  data_type: ^node,
  allocator: ^node,
  directive: string, // TODO as node?
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

statements: []node_type = { .assignment_statement, .basic_for_statement, .break_statement, .continue_statement, .if_statement, .ranged_for_statement, .return_statement, .scope_statement }
binary_operators: []node_type = { .add, .and, .bitwise_and, .bitwise_or, .divide, .equal, .greater_than, .greater_than_or_equal, .less_than, .less_than_or_equal, .modulo, .multiply, .not_equal, .or, .subtract }
comparison_operators: []node_type = { .equal, .greater_than, .greater_than_or_equal, .less_than, .less_than_or_equal, .not_equal }
literals: []node_type = { .boolean_literal, .compound_literal, .nil_literal, .number_literal, .string_literal }
complex_types: []node_type = { .enum_type, .module_type, .procedure_type, .struct_type }

simple_types: []string = { "[any_float]", "[any_int]", "[any_number]", "[any_string]", "[none]", "atomic_i8", "atomic_i16", "atomic_i32", "atomic_i64", "bool", "cint", "cuint", "f32", "f64", "i8", "i16", "i32", "i64", "u8", "u16", "u32", "u64" }
