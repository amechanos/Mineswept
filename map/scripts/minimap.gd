class_name MinimapRenderer
extends Node2D

@export var cell_size: int = 24
@export var wall_thickness: float = 3.0
@export var room_color: Color = Color(0.6, 0.6, 0.6, 1.0)
@export var wall_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var current_node_index: int = 1

func _ready() -> void:
	current_node_index = Map.current_node
	queue_redraw()

func _draw() -> void:
	if Map.discovered_nodes.is_empty():
		return
	
	var w = Map.map_width
	var h = Map.map_height
	
	var total_width = w * cell_size
	var total_height = h * cell_size
	var offset = Vector2(cell_size, cell_size) 
	
	for node in Map.discovered_nodes:
		var cell: MapCell = Map.map_nodes_array[node-1]
		
		var x = int(cell.grid_position.x)
		var y = int(cell.grid_position.y)
		
		var pos = offset + Vector2(x * cell_size, y * cell_size)
		var rect = Rect2(pos, Vector2(cell_size, cell_size))
		
		draw_rect(rect, room_color)
		
		# Walls (only draw if not connected)
		var wall_half = wall_thickness / 2.0
		
		if not cell.path_top:
			draw_rect(Rect2(pos.x, pos.y - wall_half, cell_size, wall_thickness), wall_color)
		if not cell.path_bottom:
			draw_rect(Rect2(pos.x, pos.y + cell_size - wall_half, cell_size, wall_thickness), wall_color)
		if not cell.path_left:
			draw_rect(Rect2(pos.x - wall_half, pos.y, wall_thickness, cell_size), wall_color)
		if not cell.path_right:
			draw_rect(Rect2(pos.x + cell_size - wall_half, pos.y, wall_thickness, cell_size), wall_color)
	
	# Draw player dot
	var current_cell: MapCell = Map.map_nodes_array[current_node_index - 1]
	var cx = int(current_cell.grid_position.x)
	var cy = int(current_cell.grid_position.y)
	var current_center = offset + Vector2(
		cx * cell_size + cell_size / 2.0,
		cy * cell_size + cell_size / 2.0
	)
	draw_circle(current_center, cell_size * 0.25, Color.WHITE)
