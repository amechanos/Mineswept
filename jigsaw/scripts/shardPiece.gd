class_name shardPiece
extends Node2D

var correct_rotation: Array[float] = [0.0, 180.0]
var is_placed: bool = false
var grid_pos: Vector2i
var piece_size: Vector2
var polygon: PackedVector2Array
var centroid: Vector2 = Vector2.ZERO        # <— ADD

signal drag_started(piece: shardPiece)      # <— ADD
signal drag_moved(piece: shardPiece, delta: Vector2)  # <— ADD
signal drag_ended(piece: shardPiece)

var dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

func _ready():
	z_index = 0
	set_process_input(true)

func is_point_inside(global_pt: Vector2) -> bool:
	return Geometry2D.is_point_in_polygon(to_local(global_pt), polygon)

func _input(event: InputEvent):
	# REMOVED: if is_placed: return   (snapped pieces must still be draggable)
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if is_point_inside(get_global_mouse_position()):
				dragging = true
				drag_offset = get_global_mouse_position() - global_position
				z_index = 100
				drag_started.emit(self)     # <— ADD
				get_viewport().set_input_as_handled()
		else:
			if dragging:
				dragging = false
				drag_ended.emit(self)
				get_viewport().set_input_as_handled()

	if dragging and event is InputEventMouseMotion:
		var new_pos := get_global_mouse_position() - drag_offset
		var delta := new_pos - global_position
		global_position = new_pos
		drag_moved.emit(self, delta)        # <— ADD
		get_viewport().set_input_as_handled()

	# Disable individual rotation once snapped (prevents breaking the group)
	if not dragging and not is_placed:      # <— ADD "and not is_placed"
		if Input.is_action_pressed("rotateCW") and _is_mouse_over():
			rotation_degrees += 90.0
			get_viewport().set_input_as_handled()
		if Input.is_action_pressed("rotateCC") and _is_mouse_over():
			rotation_degrees -= 90.0
			get_viewport().set_input_as_handled()
			
func _is_mouse_over() -> bool:
	var local_mouse := to_local(get_global_mouse_position())
	return Geometry2D.is_point_in_polygon(local_mouse, polygon)
