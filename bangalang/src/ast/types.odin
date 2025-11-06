package ast

import "../src"

node :: struct
{
  type: node_type,
  value: string,
  data_type: ^node,
  allocator: string, // TODO as node?
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
  equal,
  greater_than,
  greater_than_or_equal,
  identifier,
  if_statement,
  index,
  less_than,
  less_than_or_equal,
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
  ranged_for_statement,
  reference,
  return_statement,
  scope_statement,
  string_literal,
  subtract,
  subtract_assign,
  switch_,
  type
}

statements: []node_type = { .assignment_statement, .basic_for_statement, .break_statement, .continue_statement, .if_statement, .ranged_for_statement, .return_statement, .scope_statement }
binary_operators: []node_type = { .add, .and, .bitwise_and, .bitwise_or, .divide, .equal, .greater_than, .greater_than_or_equal, .less_than, .less_than_or_equal, .modulo, .multiply, .not_equal, .or, .subtract }
comparison_operators: []node_type = { .equal, .greater_than, .greater_than_or_equal, .less_than, .less_than_or_equal, .not_equal }
literals: []node_type = { .boolean_literal, .compound_literal, .nil_literal, .number_literal, .string_literal }
