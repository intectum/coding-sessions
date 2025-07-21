package main

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

non_atomic_integer_tests: []string = { "negate" /* TODO re-add */, "add", "add_assign", "subtract", "subtract_assign", "multiply", "multiply_assign", "divide", "divide_assign", "modulo", "modulo_assign", "bedmas_1", "bedmas_2", "bedmas_3", "bedmas_4" }

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

    uncommented_code = 1
  `

  general_tests["if_false_scope"] =
  `
    var0 = false
    if false
    {
        var0 = true
    }
    assert(var0 == false, "")
  `

  general_tests["if_false_scope_brackets"] =
  `
    var0 = false
    if (false)
    {
        var0 = true
    }
    assert(var0 == false, "")
  `

  general_tests["if_true_scope"] =
  `
    var0 = false
    if true
    {
        var0 = true
    }
    assert(var0, "")
  `

  general_tests["if_false_non_scope"] =
  `
    var0 = false
    if false var0 = true
    assert(var0 == false, "")
  `

  general_tests["if_true_non_scope"] =
  `
    var0 = false
    if true var0 = true
    assert(var0, "")
  `

  general_tests["if_else_true_scope"] =
  `
    var0: i8 = 0
    if true
    {
        var0 = 1
    }
    else
    {
        var0 = 2
    }
    assert(var0 == 1, "")
  `

  general_tests["if_else_false_scope"] =
  `
    var0: i8 = 0
    if false
    {
        var0 = 1
    }
    else
    {
        var0 = 2
    }
    assert(var0 == 2, "")
  `

  general_tests["if_else_true_non_scope"] =
  `
    var0: i8 = 0
    if true var0 = 1
    else var0 = 2
    assert(var0 == 1, "")
  `

  general_tests["if_else_false_non_scope"] =
  `
    var0: i8 = 0
    if false var0 = 1
    else var0 = 2
    assert(var0 == 2, "")
  `

  general_tests["if_else_if_true_true_scope"] =
  `
    var0: i8 = 0
    if true
    {
        var0 = 1
    }
    else if true
    {
        var0 = 2
    }
    else
    {
        var0 = 3
    }
    assert(var0 == 1, "")
  `

  general_tests["if_else_if_true_true_scope_brackets"] =
  `
    var0: i8 = 0
    if (true)
    {
        var0 = 1
    }
    else if (true)
    {
        var0 = 2
    }
    else
    {
        var0 = 3
    }
    assert(var0 == 1, "")
  `

  general_tests["if_else_if_false_true_scope"] =
  `
    var0: i8 = 0
    if false
    {
        var0 = 1
    }
    else if true
    {
        var0 = 2
    }
    else
    {
        var0 = 3
    }
    assert(var0 == 2, "")
  `

  general_tests["if_else_if_false_false_scope"] =
  `
    var0: i8 = 0
    if false
    {
        var0 = 1
    }
    else if false
    {
        var0 = 2
    }
    else
    {
        var0 = 3
    }
    assert(var0 == 3, "")
  `

  general_tests["if_else_if_true_true_non_scope"] =
  `
    var0: i8 = 0
    if true var0 = 1
    else if true var0 = 2
    else var0 = 3
    assert(var0 == 1, "")
  `

  general_tests["if_else_if_false_true_non_scope"] =
  `
    var0: i8 = 0
    if false var0 = 1
    else if true var0 = 2
    else var0 = 3
    assert(var0 == 2, "")
  `

  general_tests["if_else_if_false_false_non_scope"] =
  `
    var0: i8 = 0
    if false var0 = 1
    else if false var0 = 2
    else var0 = 3
    assert(var0 == 3, "")
  `

  general_tests["for_expression_scope"] =
  `
    sum: i64 = 0
    value: i64 = 10
    for value > 0
    {
        sum += value
        value -= 1
    }
    assert(sum == 55, "")
  `

  general_tests["for_pre_expression_scope"] =
  `
    sum: i64 = 0
    for value: i64 = 10, value > 0
    {
        sum += value
        value -= 1
    }
    assert(sum == 55, "")
    value: bool // 'value' above is no longer in scope
  `

  general_tests["for_pre_expression_post_scope"] =
  `
    sum: i64 = 0
    for value: i64 = 10, value > 0, value = value - 1
    {
        sum += value
    }
    assert(sum == 55, "")
    value: bool // 'value' above is no longer in scope
  `

  general_tests["for_pre_expression_post_non_scope_brackets"] =
  `
    sum: i64 = 0
    for (value: i64 = 10, value > 0, value = value - 1) sum += value
    assert(sum == 55, "")
    value: bool // 'value' above is no longer in scope
  `

  value_tests: map[string]string

  // TODO
  /*value_tests["declare"] =
  `
    var0: <type>
    assert(var0 == nil, "")
  `*/

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

  value_tests["declare_then_assign_array_of_arrays"] =
  `
    var0: <type>[10][10]
    var0[5][5] = <value0>
    assert(var0[5][5] == <value0>, "")
  `

  // TODO
  /*value_tests["declare_then_assign_array_of_structs"] =
  `
    var0: struct { member0: <type>, member1: <type> }[10]
    var0[5].member0 = <value0>
    var0[5].member1 = <value1>
    assert(var0[5].member0 == <value0>, "")
    assert(var0[5].member1 == <value1>, "")
  `*/

  value_tests["declare_and_assign_slice"] =
  `
    var0: <type>[10]
    var0[5] = <value0>
    var1 = var0[2:8]
    assert(var1[3] == <value0>, "")
  `

  value_tests["declare_then_assign_slice"] =
  `
    var0: <type>[10]
    var0[5] = <value0>
    var1: <type>[]
    var1 = var0[2:8]
    assert(var1[3] == <value0>, "")
  `

  value_tests["declare_and_assign_slice_from_literal"] =
  `
    var0: <type>[10]
    var0[5] = <value0>
    var1: <type>[] = { raw = ^var0[0], length = 10 }
    assert(var1[5] == <value0>, "")
  `

  value_tests["declare_then_assign_slice_from_literal"] =
  `
    var0: <type>[10]
    var0[5] = <value0>
    var1: <type>[]
    var1 = { raw = ^var0[0], length = 10 }
    assert(var1[5] == <value0>, "")
  `

  value_tests["declare_and_assign_slice_of_arrays"] =
  `
    var0: <type>[10][10]
    var0[5][5] = <value0>
    var1 = var0[2:8]
    assert(var1[3][5] == <value0>, "")
  `

  value_tests["declare_then_assign_slice_of_arrays"] =
  `
    var0: <type>[10][10]
    var0[5][5] = <value0>
    var1: <type>[10][]
    var1 = var0[2:8]
    assert(var1[3][5] == <value0>, "")
  `

  value_tests["declare_and_assign_struct"] =
  `
    var0: struct { member0: <type>, member1: <type> } = { member0 = <value0>, member1 = <value1> }
    assert(var0.member0 == <value0>, "")
    assert(var0.member1 == <value1>, "")
  `

  value_tests["declare_then_assign_struct"] =
  `
    var0: struct { member0: <type>, member1: <type> }
    var0 = { member0 = <value0>, member1 = <value1> }
    assert(var0.member0 == <value0>, "")
    assert(var0.member1 == <value1>, "")
  `

  value_tests["declare_then_assign_struct_member"] =
  `
    var0: struct { member0: <type>, member1: <type> }
    var0.member0 = <value0>
    var0.member1 = <value1>
    assert(var0.member0 == <value0>, "")
    assert(var0.member1 == <value1>, "")
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

  value_tests["declare_and_assign_pointer_to_slice"] =
  `
    var0: <type>[10]
    var0[5] = <value0>
    var1 = var0[2:8]
    var2 = ^var1
    assert(var2[3] == <value0>, "")
  `

  value_tests["proc_param_scope"] =
  `
    proc0: proc(param0: <type>) =
    {
      assert(param0 == <value0>, "")
    }
    proc0(<value0>)
  `

  value_tests["proc_return_scope"] =
  `
    proc0: proc() -> <type> =
    {
      return <value0>
    }
    assert(proc0() == <value0>, "")
  `

  value_tests["proc_param_non_scope"] =
  `
    proc0: proc(param0: <type>) = assert(param0 == <value0>, "")
    proc0(<value0>)
  `

  value_tests["proc_return_non_scope"] =
  `
    proc0: proc() -> <type> = return <value0>
    assert(proc0() == <value0>, "")
  `

  value_tests["proc_return_non_scope_expression_only"] =
  `
    proc0: proc() -> <type> = <value0>
    assert(proc0() == <value0>, "")
  `

  value_tests["type_alias"] =
  `
    type0 = <type>
    var0: type0 = <value0>
    assert(var0 == <value0>, "")
  `

  value_tests["type_alias_array"] =
  `
    type0 = <type>[10]
    var0: type0
    var0[5] = <value0>
    assert(var0[5] == <value0>, "")
  `

  // TODO
  /*value_tests["type_alias_slice"] =
  `
    type0 = <type>[]
    var0: <type>[10]
    var0[5] = <value0>
    var1: type0 = var0[2:8]
    assert(var1[3] == <value0>, "")
  `*/

  value_tests["type_alias_struct"] =
  `
    type0 = struct { member0: <type>, member1: <type> }
    var0: type0
    var0.member0 = <value0>
    var0.member1 = <value1>
    assert(var0.member0 == <value0>, "")
    assert(var0.member1 == <value1>, "")
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

  bool_tests["and"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var0 && var0, "")
    assert((var0 && var1) == false, "")
    assert((var1 && var1) == false, "")
  `

  bool_tests["or"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(var0 || var0, "")
    assert(var0 || var1, "")
    assert(var1 || var1 == false, "")
  `

  bool_tests["not"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    assert(!var0 == false, "")
    assert(!var1 == true, "")
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

  numerical_tests["bedmas_1"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    var2: <type> = <value2>
    assert(var2 + var1 * var0 == 14, "")
  `

  numerical_tests["bedmas_2"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    var2: <type> = <value2>
    assert(var2 - var1 / var0 == 4, "")
  `

  numerical_tests["bedmas_3"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    var2: <type> = <value2>
    assert((var2 + var1) * var0 == 20, "")
  `

  numerical_tests["bedmas_4"] =
  `
    var0: <type> = <value0>
    var1: <type> = <value1>
    var2: <type> = <value2>
    assert((var2 - var1) / var0 == 1, "")
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
    bool_src, _ = strings.replace_all(bool_src, "<value1>", "false")
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
      numerical_src, _ = strings.replace_all(numerical_src, "<value1>", "2")
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
      if numerical_type == "i8" && (numerical_test == "multiply" || numerical_test == "multiply_assign" || numerical_test == "modulo" || numerical_test == "modulo_assign" || numerical_test == "bedmas_1" || numerical_test == "bedmas_3")
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
