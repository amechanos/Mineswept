extends Node2D

@export var snap_distance: float = 33.0
@export var snap_angle_tolerance: float = 8.0
@export var scatter_margin: float = 60.0

signal puzzle_completed

var _pieces: Array[shardPiece] = []
var _board_size: Vector2 = Vector2.ZERO

var _groups: Dictionary = {}
var _next_group_id: int = 0

func _ready():
	load_found_shards()
	print($board.get_children())

# ------------------------------------------------------------------
# Load all shards from Global.foundShards regardless of card
# ------------------------------------------------------------------
func load_found_shards() -> void:
	for p in _pieces:
		p.queue_free()
	_pieces.clear()
	_groups.clear()
	_next_group_id = 0

	if Global.foundShards.is_empty():
		push_warning("AssemblyScene: Global.foundShards is empty, nothing to load.")
		return

	var saved: Array = Global.assemblyState.get("assembly", [])
	var spawn_index: int = 0

	for card_name in Global.foundShards.keys():
		var shards: Array = Global.foundShards[card_name]
		for data: shardData in shards:
			var piece := shardPiece.new()
			piece.correct_rotation = data.correct_rotation
			piece.grid_pos = data.grid_pos
			piece.piece_size = data.piece_size
			piece.polygon = data.polygon
			piece.centroid = data.centroid
			piece.is_placed = false

			piece.set_meta("card", data.card)

			var visual := Polygon2D.new()
			visual.polygon = data.polygon
			visual.uv = data.uv
			# Fetch the card's texture from ShardLibrary or wherever you store it.
			visual.texture = _get_texture_for_card(data.card)
			piece.add_child(visual)

			var outline := Polygon2D.new()
			outline.polygon = data.polygon
			outline.color = Color(0, 0, 0, 0.3)
			outline.position = Vector2(2, 2)
			piece.add_child(outline)
			piece.move_child(outline, 0)

			piece.drag_started.connect(_on_piece_drag_started)
			piece.drag_moved.connect(_on_piece_drag_moved)
			piece.drag_ended.connect(_on_piece_drag_ended)

			$board.add_child(piece)
			_pieces.append(piece)
					
			if spawn_index < saved.size():
				var s_data = saved[spawn_index]
				piece.global_position  = s_data["position"]
				piece.rotation_degrees = s_data["rotation"]
				piece.is_placed = s_data["is_placed"]
				
				var saved_group_id = s_data.get("group_id", -1)
				if saved_group_id != -1:
					if not _groups.has(saved_group_id):
						# CHANGE HERE: Explicitly type the empty array
						var new_typed_array: Array[shardPiece] = []
						_groups[saved_group_id] = new_typed_array
						
					_groups[saved_group_id].append(piece)
					
					# Ensure new groups created later don't overwrite loaded ones
					_next_group_id = max(_next_group_id, saved_group_id + 1)
				elif piece.is_placed:
					# Fallback just in case a piece is placed but has no group
					_create_group([piece])
			else:
				_scatter_piece(piece)

			spawn_index += 1

func _get_texture_for_card(card_name: String) -> Texture2D:
	var path := "res://tarot/cards/" + card_name + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	push_warning("AssemblyScene: no texture found for card '%s'" % card_name)
	return null

# ------------------------------------------------------------------
# State persistence
# ------------------------------------------------------------------
func save_state() -> void:
	var snapshot: Array = []
	for piece in _pieces:
		# Find which group this piece belongs to
		var current_group_id: int = -1
		for id in _groups.keys():
			if piece in _groups[id]:
				current_group_id = id
				break
				
		snapshot.append({
			"position":  piece.global_position,
			"rotation":  piece.rotation_degrees,
			"is_placed": piece.is_placed,
			"group_id":  current_group_id # <-- Save the ID!
		})
	Global.assemblyState["assembly"] = snapshot

func _scatter_piece(piece: shardPiece) -> void:
	piece.position = Vector2(
		randf_range(100.0, 1180.0),
		randf_range(100.0, 620.0)
	)
	piece.rotation_degrees = (randi() % 4) * 90.0

# ------------------------------------------------------------------
# Group helpers
# ------------------------------------------------------------------
func _get_group(piece: shardPiece) -> Array[shardPiece]:
	for id in _groups.keys():
		if piece in _groups[id]:
			# Force the dictionary array into a strictly typed array
			var typed_group: Array[shardPiece] = []
			typed_group.assign(_groups[id])
			return typed_group
			
	# Explicitly type the fallback array
	var fallback: Array[shardPiece] = [piece]
	return fallback

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
	if _groups[id1].size() < _groups[id2].size():
		var tmp = id1
		id1 = id2
		id2 = tmp
	for p in _groups[id2]:
		p.is_placed = true
	_groups[id1].append_array(_groups[id2])
	_groups.erase(id2)

# ------------------------------------------------------------------
# Dragging
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
	save_state()

# ------------------------------------------------------------------
# Snapping — only allows snapping between shards of the same card
# ------------------------------------------------------------------
func _try_snap_group(group: Array[shardPiece]) -> bool:
	for piece in group:
		for other in _pieces:
			if other == piece or other in group:
				continue

			# Shards from different cards must never snap together.
			if piece.get_meta("card") != other.get_meta("card"):
				continue

			var grid_diff = piece.grid_pos - other.grid_pos
			if abs(grid_diff.x) + abs(grid_diff.y) != 1:
				continue

			var expected_offset = Vector2(
				grid_diff.x * piece.piece_size.x, 
				grid_diff.y * piece.piece_size.y
			) + (piece.centroid - other.centroid)

			var expected_pos = other.global_position + expected_offset

			if piece.global_position.distance_to(expected_pos) > snap_distance:
				continue

			var rot_diff = fmod(piece.rotation_degrees - other.rotation_degrees, 360.0)
			if rot_diff < 0.0:
				rot_diff += 360.0
			if rot_diff > 180.0:
				rot_diff = 360.0 - rot_diff

			if rot_diff > snap_angle_tolerance:
				continue

			var snap_delta = expected_pos - piece.global_position
			for p in group:
				p.global_position += snap_delta
				p.rotation_degrees = other.rotation_degrees

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

# ------------------------------------------------------------------
# Completion — checks per card, not globally
# ------------------------------------------------------------------
func _check_completion() -> void:
	# Build a count of how many shards exist per card in foundShards.
	var total_per_card: Dictionary = {}
	for card_name in Global.foundShards.keys():
		total_per_card[card_name] = Global.foundShards[card_name].size()

	# Also check how many shards exist per card in lostShards,
	# because a card is only completable once all its shards are found.
	var placed_per_card: Dictionary = {}
	for piece in _pieces:
		var card = piece.get_meta("card")
		if not placed_per_card.has(card):
			placed_per_card[card] = 0
		if piece.is_placed:
			placed_per_card[card] += 1

	for card_name in total_per_card.keys():
		var lost_count: int = Global.lostShards.get(card_name, []).size()
		# Only count a card complete if no shards are still lost
		# and every found shard is placed.
		if lost_count == 0 and placed_per_card.get(card_name, 0) == total_per_card[card_name]:
			Global.completedCards.append(card_name)
			print("Card complete: %s" % card_name)

func _on_button_pressed() -> void:
	save_state()
	get_tree().change_scene_to_file("res://minesweeper/board.tscn")
