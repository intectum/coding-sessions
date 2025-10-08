package ast

import "../src"

node :: struct
{
  type: node_type,
  value: string,
  allocator: string, // TODO as node?
  directive: string, // TODO as node?
  children: [dynamic]node,
  src_position: src.position
}

node_type :: enum
{
  none,
  add,
  add_assign,
  and,
  assign,
  assignment,
  bitwise_and,
  bitwise_and_assign,
  bitwise_or,
  bitwise_or_assign,
  boolean,
  break_,
  call,
  compound_literal,
  continue_,
  dereference,
  divide,
  divide_assign,
  equal,
  for_,
  greater_than,
  greater_than_or_equal,
  identifier,
  if_,
  index,
  less_than,
  less_than_or_equal,
  modulo,
  modulo_assign,
  multiply,
  multiply_assign,
  negate,
  nil_,
  not,
  not_equal,
  number,
  or,
  reference,
  return_,
  scope,
  string_,
  subtract,
  subtract_assign,
  type
}

statements: []node_type = { .assignment, .break_, .continue_, .for_, .if_, .return_, .scope }
binary_operators: []node_type = { .add, .and, .bitwise_and, .bitwise_or, .divide, .equal, .greater_than, .greater_than_or_equal, .less_than, .less_than_or_equal, .modulo, .multiply, .not_equal, .or, .subtract }
comparison_operators: []node_type = { .equal, .greater_than, .greater_than_or_equal, .less_than, .less_than_or_equal, .not_equal }
literals: []node_type = { .boolean, .compound_literal, .nil_, .number, .string_ }
