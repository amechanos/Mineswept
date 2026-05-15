extends Node2D

@export var puzzle_texture: Texture2D
@export var rows: int = 4
@export var cols: int = 6
@export var snap_distance: float = 25.0
@export var snap_angle_tolerance: float = 8.0
@export var scatter_margin: float = 60.0

signal puzzle_completed

var _pieces: Array[shardPiece] = []
var _board_size: Vector2 = Vector2.ZERO
var _piece_size: Vector2 = Vector2.ZERO

# Group tracking  <— ADD
var _groups: Dictionary = {}   # int -> Array[shardPiece]
var _next_group_id: int = 0

func _ready():
	if puzzle_texture:
		generate_puzzle()
	else:
		push_warning("JigsawPuzzle: No puzzle_texture assigned!")

func generate_puzzle():
	for p in _pieces:
		p.queue_free()
	_pieces.clear()
	_groups.clear()
	_next_group_id = 0

	var cutter := JigsawCutter.new()
	cutter.tab_size = min(puzzle_texture.get_width() / cols, puzzle_texture.get_height() / rows) * 0.18
	var data_array := cutter.cut_image(puzzle_texture, rows, cols)

	_board_size = Vector2(puzzle_texture.get_width(), puzzle_texture.get_height())
	_piece_size = Vector2(puzzle_texture.get_width() / cols, puzzle_texture.get_height() / rows)

	for data in data_array:
		var piece := shardPiece.new()
		piece.correct_rotation = data.correct_rotation
		piece.grid_pos = data.grid_pos
		piece.polygon = data.polygon
		piece.centroid = data.centroid
		piece.is_placed = false

		var visual := Polygon2D.new()
		visual.polygon = data.polygon
		visual.uv = data.uv
		visual.texture = puzzle_texture
		piece.add_child(visual)

		var outline := Polygon2D.new()
		outline.polygon = data.polygon
		outline.color = Color(0, 0, 0, 0.3)
		outline.position = Vector2(2, 2)
		piece.add_child(outline)
		piece.move_child(outline, 0)

		# Connect new signals  <— ADD
		piece.drag_started.connect(_on_piece_drag_started)
		piece.drag_moved.connect(_on_piece_drag_moved)
		piece.drag_ended.connect(_on_piece_drag_ended)

		$board.add_child(piece)
		_pieces.append(piece)
		_scatter_piece(piece)

func _scatter_piece(piece: shardPiece):
	piece.position = Vector2(
		randf_range(100.0, 1180.0),
		randf_range(100.0, 620.0)
	)
	piece.rotation_degrees = (randi() % 4) * 90.0

# ------------------------------------------------------------------
# Group helpers  <— ADD
# ------------------------------------------------------------------
func _get_group(piece: shardPiece) -> Array[shardPiece]:
	for id in _groups.keys():
		if piece in _groups[id]:
			return _groups[id]
	return [piece]

func _create_group(pieces: Array[shardPiece]) -> int:
	var id = _next_group_id
	_next_group_id += 1
	_groups[id] = pieces.duplicate()
	for p in pieces:
		p.is_placed = true
	return id

func _add_to_group(piece: shardPiece, group_id: int) -> void:
	if not _groups.has(group_id):
		return
	if piece not in _groups[group_id]:
		_groups[group_id].append(piece)
	piece.is_placed = true

func _merge_groups(id1: int, id2: int) -> void:
	if id1 == id2:
		return
	if not _groups.has(id1) or not _groups.has(id2):
		return
	# Merge smaller into larger to keep it tidy
	if _groups[id1].size() < _groups[id2].size():
		var tmp = id1
		id1 = id2
		id2 = tmp
	for p in _groups[id2]:
		p.is_placed = true
	_groups[id1].append_array(_groups[id2])
	_groups.erase(id2)

# ------------------------------------------------------------------
# Dragging  <— ADD
# ------------------------------------------------------------------
func _on_piece_drag_started(piece: shardPiece) -> void:
	var group = _get_group(piece)
	for p in group:
		p.z_index = 100

func _on_piece_drag_moved(piece: shardPiece, delta: Vector2) -> void:
	var group = _get_group(piece)
	if group.size() > 1:
		for p in group:
			if p != piece:
				p.global_position += delta

func _on_piece_drag_ended(piece: shardPiece) -> void:
	var group = _get_group(piece)
	for p in group:
		p.z_index = 0
	_try_snap_group(group)
	_check_completion()

# ------------------------------------------------------------------
# Snapping (piece-to-piece only, group-aware)  <— REPLACED
# ------------------------------------------------------------------
func _try_snap_group(group: Array[shardPiece]) -> bool:
	for piece in group:
		for other in _pieces:
			if other == piece or other in group:
				continue

			# Must be neighbours in the original grid
			var grid_diff = piece.grid_pos - other.grid_pos
			if abs(grid_diff.x) + abs(grid_diff.y) != 1:
				continue

			# Expected relative offset (centroids handle tab/blank asymmetry)
			var expected_offset = Vector2(
				grid_diff.x * _piece_size.x,
				grid_diff.y * _piece_size.y
			) + (piece.centroid - other.centroid)

			var expected_pos = other.global_position + expected_offset

			# Distance check
			if piece.global_position.distance_to(expected_pos) > snap_distance:
				continue

			# Relative rotation must be ~0 (same orientation)
			var rot_diff = fmod(piece.rotation_degrees - other.rotation_degrees, 360.0)
			if rot_diff < 0.0:
				rot_diff += 360.0
			if rot_diff > 180.0:
				rot_diff = 360.0 - rot_diff

			if rot_diff > snap_angle_tolerance:
				continue

			# Both pieces must be at an individually valid rotation (e.g. 0° or 180°)
			if not _is_rotation_correct(piece) or not _is_rotation_correct(other):
				continue

			var snap_delta = expected_pos - piece.global_position
			for p in group:
				p.global_position += snap_delta
				p.rotation_degrees = other.rotation_degrees

			# Merge the other piece (or its whole group) into this group
			var group_id = -1
			for id in _groups.keys():
				if piece in _groups[id]:
					group_id = id
					break

			var other_group_id = -1
			for id in _groups.keys():
				if other in _groups[id]:
					other_group_id = id
					break

			if group_id == -1 and other_group_id == -1:
				_create_group([piece, other])
			elif group_id != -1 and other_group_id == -1:
				_add_to_group(other, group_id)
			elif group_id == -1 and other_group_id != -1:
				_add_to_group(piece, other_group_id)
			else:
				_merge_groups(group_id, other_group_id)

			return true
	return false

func _is_rotation_correct(piece: shardPiece) -> bool:
	var rot = fmod(piece.rotation_degrees, 360.0)
	if rot < 0.0:
		rot += 360.0
	for correct_rot in piece.correct_rotation:
		var diff = abs(rot - correct_rot)
		if diff <= snap_angle_tolerance or diff >= 360.0 - snap_angle_tolerance:
			return true
	return false

func _check_completion():
	for piece in _pieces:
		if not piece.is_placed:
			return
	puzzle_completed.emit()
	print("Puzzle Complete!")
