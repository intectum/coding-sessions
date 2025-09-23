package glsl

import "core:strconv"
import "core:strings"

import "../../ast"

type_name :: proc(type_node: ^ast.node) -> string
{
    assert(type_node.type == .type, "Invalid type")

    switch type_node.value
    {
    case "[array]":
        child_type_name := type_name(&type_node.children[0])
        length := strconv.atoi(type_node.children[1].value)
        if child_type_name == "f32" && length >= 2 && length <= 4
        {
            return strings.concatenate({ "vec", type_node.children[1].value })
        }
        return strings.concatenate({ type_name(&type_node.children[0]), "[", type_node.children[1].value, "]" })
    case "[procedure]":
        assert(false, "Unsupported type name")
    case "[slice]":
        assert(false, "Unsupported type name")
    case "i8":
        return "int8_t"
    case "i16":
        return "int16_t"
    case "i32":
        return "int32_t"
    case "i64":
        return "int64_t"
    }

    return type_node.value
}
