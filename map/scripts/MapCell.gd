class_name MapCell
extends RefCounted

var grid_position: Vector2

# Path connections
var path_left: bool = false
var path_right: bool = false
var path_top: bool = false
var path_bottom: bool = false

func _init(pos: Vector2):
	grid_position = pos

# Optional: A helper function to print the node's data nicely in the console
func _to_string() -> String:
	return "Node(%v) -> [L:%s, R:%s, T:%s, B:%s]" % [grid_position, path_left, path_right, path_top, path_bottom]
