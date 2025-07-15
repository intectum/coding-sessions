package main

import "core:fmt"
import "core:os"
import "core:strings"
import slice "core:slice"

non_atomic_integer_tests: []string = { "negate" /* TODO re-add */, "add", "add_assign", "subtract", "subtract_assign", "multiply", "multiply_assign", "divide", "divide_assign", "modulo", "modulo_assign" }

run_test_suite :: proc() -> (failed_tests: [dynamic]string)
{
  general_tests: map[string]string

  general_tests["comments"] =
`
uncommented_code: i8 = 1

// Single-line comment

/*
  Multi-line comment

  /*
    Nested multi-line comment!
  */

  // Multi-line close */

  "Multi-line close */"

*/

uncommented_code: i8 = 1
`

  value_tests: map[string]string

  value_tests["declare_and_assign"] =
`
  var0: <type> = <value0>
  assert(var0 == <value0>, "")
`

  value_tests["declare_then_assign"] =
  `
    var0: <type>
    var0 = <value0>
    assert(var0 == <value0>, "")
  `

  value_tests["declare_then_assign_array"] =
  `
    var0: <type>[10]
    var0[5] = <value0>
    assert(var0[5] == <value0>, "")
  `

  value_tests["declare_and_assign_pointer"] =
  `
    var0: <type> = <value0>
    var1 = ^var0
    assert(var1^ == <value0>, "")
  `

  value_tests["declare_and_assign_pointer_to_array"] =
  `
    var0: <type>[10]
    var0[5] = <value0>
    var1 = ^var0
    assert(var1[5] == <value0>, "")
  `

  bool_tests: map[string]string

  bool_tests["equal"] =
  `
    var0: <type> = <value0>
    assert(var0 == var0, "")
  `

  bool_tests["not_equal"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var0 != var1, "")
  `

  numerical_tests: map[string]string

  numerical_tests["equal"] =
  `
    var0: <type> = <value0>
    assert(var0 == var0, "")
  `

  numerical_tests["not_equal"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var0 != var1, "")
  `

  numerical_tests["less_than"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var0 < var1, "")
    assert(var0 < var0 == false, "")
    assert(var1 < var0 == false, "")
  `

  numerical_tests["greater_than"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var0 > var1 == false, "")
    assert(var0 > var0 == false, "")
    assert(var1 > var0, "")
  `

  numerical_tests["less_than_or_equal"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var0 <= var1, "")
    assert(var0 <= var0, "")
    assert(var1 <= var0 == false, "")
  `

  numerical_tests["greater_than_or_equal"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var0 >= var1 == false, "")
    assert(var0 >= var0, "")
    assert(var1 >= var0, "")
  `

  numerical_tests["negate"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var1 + -var0 == 2, "")
  `

  numerical_tests["add"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var1 + var0 == 6, "")
  `

  numerical_tests["add_assign"] =
  `
    var0: <type> = <value0>
    var0 += 2
    assert(var0 == 4, "")
  `

  numerical_tests["subtract"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var1 - var0 == 2, "")
  `

  numerical_tests["subtract_assign"] =
  `
    var0: <type> = <value0>
    var0 -= 2
    assert(var0 == 0, "")
  `

  numerical_tests["multiply"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var1 * var0 == 8, "")
  `

  numerical_tests["multiply_assign"] =
  `
    var0: <type> = <value0>
    var0 *= 2
    assert(var0 == 4, "")
  `

  numerical_tests["divide"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var1 / var0 == 2, "")
  `

  numerical_tests["divide_assign"] =
  `
    var0: <type> = <value0>
    var0 /= 2
    assert(var0 == 1, "")
  `

  numerical_tests["modulo"] =
  `
    var0: <type> = <value1>
    assert(var0 % 3 == 1, "")
  `

  numerical_tests["modulo_assign"] =
  `
    var0: <type> = <value1>
    var0 /= 3
    assert(var0 == 1, "")
  `

  // TODO unknown identifier as type
  // TODO value used as type
  // TODO type used as value

  for general_test in general_tests
  {
    if !run_test(general_test, general_tests[general_test])
    {
      append(&failed_tests, general_test)
    }
  }

  for value_test in value_tests
  {
    bool_src, _ := strings.replace_all(value_tests[value_test], "<type>", "bool")
    bool_src, _ = strings.replace_all(bool_src, "<value0>", "true")
    if !run_test(value_test, bool_src)
    {
      append(&failed_tests, fmt.aprintf("%s (%s)", value_test, "bool"))
    }

    for numerical_type in numerical_types
    {
      if numerical_type == "number"
      {
        continue
      }

      numerical_src, _ := strings.replace_all(value_tests[value_test], "<type>", numerical_type)
      numerical_src, _ = strings.replace_all(numerical_src, "<value0>", "1")
      if !run_test(value_test, numerical_src)
      {
        append(&failed_tests, fmt.aprintf("%s (%s)", value_test, numerical_type))
      }
    }
  }

  for bool_test in bool_tests
  {
    bool_src, _ := strings.replace_all(bool_tests[bool_test], "<type>", "bool")
    bool_src, _ = strings.replace_all(bool_src, "<value0>", "true")
    bool_src, _ = strings.replace_all(bool_src, "<value1>", "false")
    if !run_test(bool_test, bool_src)
    {
      append(&failed_tests, fmt.aprintf("%s (%s)", bool_test, "bool"))
    }
  }

  for numerical_test in numerical_tests
  {
    for numerical_type in numerical_types
    {
      if numerical_type == "number"
      {
        continue
      }

      // TODO re-add
      if numerical_type == "i8" && (numerical_test == "multiply" || numerical_test == "multiply_assign" || numerical_test == "modulo" || numerical_test == "modulo_assign")
      {
        continue
      }

      _, float_type := slice.linear_search(float_types, numerical_type)
      if float_type && (numerical_test == "modulo" || numerical_test == "modulo_assign")
      {
        continue
      }

      _, atomic_integer_type := slice.linear_search(atomic_integer_types, numerical_type)
      if atomic_integer_type
      {
        _, non_atomic_integer_test := slice.linear_search(non_atomic_integer_tests, numerical_test)
        if non_atomic_integer_test
        {
          continue
        }
      }

      numerical_src, _ := strings.replace_all(numerical_tests[numerical_test], "<type>", numerical_type)
      numerical_src, _ = strings.replace_all(numerical_src, "<value0>", "2")
      numerical_src, _ = strings.replace_all(numerical_src, "<value1>", "4")
      numerical_src, _ = strings.replace_all(numerical_src, "<value2>", "6")
      if !run_test(numerical_test, numerical_src)
      {
        append(&failed_tests, fmt.aprintf("%s (%s)", numerical_test, numerical_type))
      }
    }
  }

  return
}

run_test :: proc(name: string, src: string) -> bool
{
  build(name, src, "bin/test")
  return exec("bin/test") == 0
}
