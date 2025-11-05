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
        child_type_name := type_name(type_node.children[0])
        length := strconv.atoi(type_node.children[1].value)
        if child_type_name == "f32" && length >= 2 && length <= 4
        {
            return strings.concatenate({ "vec", type_node.children[1].value })
        }
        return strings.concatenate({ type_name(type_node.children[0]), "[", type_node.children[1].value, "]" })
    case "[slice]":
        return type_name(type_node.children[0])
    case "i32":
        return "int"
    case "[procedure]", "i8", "i16", "i64":
        assert(false, "Unsupported type name")
    }

    return type_node.value
}
