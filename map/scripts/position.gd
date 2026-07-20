extends Node

var temp: Vector2
var temp_i: Vector2i

var from_ui = false
var dir: String
var entry_direction: String = ""

func move(coords: Vector2, destination: String):
	temp = coords
	get_tree().change_scene_to_file(destination)
	from_ui = true

func set_player(step, player) -> void:
	var c: Vector2
	
	if from_ui:
		c = temp
	else:
		c = temp_i
		
	var vectorised = Vector2(c.x * step + step / 2, c.y * step + step / 2)
	player.global_position = vectorised
	
	#if temp and temp != Vector2.ZERO:
		#player.global_position = temp
		#temp = Vector2(step / 2, step / 2)
		#return

func on_new_board(tile: Vector2i, dir: String, height, width) -> Vector2i:
	
	match dir:
		"NORTH":
			return Vector2i(tile.x, height-1)
		"SOUTH":
			return Vector2i(tile.x, 0)
		"EAST":
			return Vector2i(0, tile.y)
		"WEST":
			return Vector2i(width-1, tile.y)
	
	print("Couldn't find relevant direction! Defaulting temp to (0,0)")
	return Vector2i.ZERO

func return_from(affected: bool, destination: String):
	var relative = temp # Since the player travelled, this is the same interaction tile of the statue
	if affected:
		var spawn_tile = find_spawn_tile(relative)
	
		Map.map[Map.current_node]["beasts"] = Map.map[Map.current_node]["beasts"].filter(
			func(beast): return beast["position"] != spawn_tile
		)
	
	print("Returning player to: ", relative)
	get_tree().change_scene_to_file(destination)
		
func find_spawn_tile(tile: Vector2) -> Vector2i:
	var tile_i = Vector2i(tile)
	
	if tile_i.y == 0:
		return tile_i + Vector2i(0, -1)
	elif tile_i.y == Global.HEIGHT - 1:
		return tile_i + Vector2i(0, 1)
	elif tile_i.x == 0:
		return tile_i + Vector2i(-1, 0)
	elif tile_i.x == Global.HEIGHT - 1:
		return tile_i + Vector2i(1, 0)

	return Vector2i.ZERO
