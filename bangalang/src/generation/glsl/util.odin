package glsl

import "core:strconv"
import "core:strings"

import "../../ast"

type_name :: proc(type_node: ^ast.node) -> string
{
    assert(ast.is_type(type_node), "Invalid type")

    if type_node.type == .subscript
    {
        if ast.is_array(type_node)
        {
            child_type_name := type_name(type_node.children[0])
            length := strconv.atoi(type_node.children[1].value)
            if child_type_name == "f32" && length >= 2 && length <= 4
            {
                return strings.concatenate({ "vec", type_node.children[1].value })
            }
            return strings.concatenate({ type_name(type_node.children[0]), "[", type_node.children[1].value, "]" })
        }
        else
        {
            return type_name(type_node.children[0])
        }
    }
    else
    {
        switch type_node.value
        {
        case "i32":
            return "int"
        case "[procedure]", "i8", "i16":
            assert(false, "Unsupported type name")
        }
    }

    return type_node.value
}
