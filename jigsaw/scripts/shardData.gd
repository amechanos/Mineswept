class_name shardData
extends RefCounted

var polygon: PackedVector2Array
var uv: PackedVector2Array
var correct_rotation: Array[float] = [0.0, 180.0]
var grid_pos: Vector2i
var piece_size: Vector2
var is_edge: bool = false
var centroid: Vector2 = Vector2.ZERO 
var card: String = " "
