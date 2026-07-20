extends Node2D

@onready var tilemap = $TileMapLayer
@onready var Player = $player
@onready var HP = $Camera/UI/Health/Value
@onready var counter = $Camera/UI/Shards/Value
@onready var list = $Camera/UI/found
@onready var camera = $Camera

@onready var npc_container = $Npcs
@onready var beast_container = $Beasts

var width: int = Global.WIDTH
var height: int = Global.HEIGHT

var npcs = []
var beasts = []

var revealed_tiles = {}
var flagged_tiles = {}
var stepped_tiles = {}
var nav_tiles = {}
var restricted_tiles = []

var pending_travel_direction := Vector2i.ZERO
var fade: float = width * 1.5
var found: int = 0

var is_travelling: bool = false
var shards = 0

const TILE = {
	# Input Tiles
	"BLANK": Vector2i(0,0),
	"CORRECT": Vector2i(1,0),
	"WRONG": Vector2i(2,0),
	"FLAG": Vector2i(3,0),
	
	# Nav Tiles
	"UP": Vector2i(0,1),
	"RIGHT": Vector2i(1,1),
	"DOWN": Vector2i(2,1),
	"LEFT": Vector2i(3,1),
	
	# Bomb Tiles
	1: Vector2i(0,2),
	2: Vector2i(1,2),
	3: Vector2i(2,2),
	4: Vector2i(3,2),
	5: Vector2i(0,3),
	6: Vector2i(1,3),
	7: Vector2i(2,3),
	8: Vector2i(3,3)
}

### Board

# Place these at the top of your script with your other variables
var beast_scene = preload("res://bosses/beast.tscn") # PLACEHOLDER
var npc_scene = preload("res://npcs/npc.tscn")     # PLACEHOLDER

func create_board(w: int, h: int, shards: int) -> Array:
	var array = []
	var map_ref = Map.map
	var id_ref = Map.map_nodes_array
	
	for i in range(w):
		array.append([])
		for j in range(h):
			tilemap.set_cell(Vector2i(i, j), 0, TILE["BLANK"])
			array[i].append(0)

	# --- INSTANTIATION SETUP ---
	
	# Fetch the predetermined positions for this specific room
	var room_key = "node-" + str(Map.current_node)
	var room_data = Map.spawn_ref.get(room_key, {"beasts": [], "npcs": []})
	print(room_data)
	var beast_positions: Array[Vector2i] = room_data["beasts"]
	var npc_positions: Array[Vector2i] = room_data["npcs"]
	
	# --- SPAWN BEASTS ---
	for b_pos in beast_positions:
		var beast = beast_scene.instantiate()
		beast.dir = fetch_dir(b_pos)
		
		beast.data = load("res://bosses/beasts/" + Map.beast_pool.pop_back())
		
		beast.spawn_tile = b_pos
		print("Position set to: ", b_pos)
		
		beast_container.add_child(beast) 
		
		beasts.append({ "data": beast.data, "position": b_pos, "direction": fetch_dir(b_pos) })
		restricted_tiles.append(beast.adjacent_tile)

	# --- SPAWN NPCs ---
	for n_pos in npc_positions:
		var npc = npc_scene.instantiate()
		npc.dir = fetch_dir(n_pos)
		
		npc.data = load("res://npcs/npc/" + Map.npc_pool.pop_back())
		
		npc.spawn_tile = n_pos
		print("Position set to: ", n_pos)
		
		npc_container.add_child(npc)
		
		npcs.append({ "data": npc.data, "position": n_pos, "direction": fetch_dir(n_pos) })
		restricted_tiles.append(npc.adjacent_tile)
		
	set_nav(w,h, Map.current_node-1)

	# --- SCATTER SHARDS ---
	var valid_shard_positions = []
	for i in range(w):
		for j in range(h):
			var pos = Vector2i(i, j)
			# Fast check against our dictionary
			if pos not in restricted_tiles and pos not in nav_tiles:
				valid_shard_positions.append(pos)
				
	valid_shard_positions.shuffle()

	var actual_shards_to_spawn = min(shards, valid_shard_positions.size())
	
	for k in range(actual_shards_to_spawn):
		var pos = valid_shard_positions[k]
		array[pos.x][pos.y] = 1 # Mark shard in grid
		
	# --- SAVE TO MAP REF ---
	if not map_ref.has(Map.current_node):
		map_ref[Map.current_node] = {
			"width": w,
			"height": h,
			"shards": shards,
			"found": 0,
			"flagged_tiles": [],
			"revealed_tiles": {},
			"restricted_tiles": restricted_tiles,
			"nav_tiles": nav_tiles,
			"grid": array,
			"beasts": beasts, 
			"npcs": npcs     
		}
		
	print("Created board: ", map_ref[Map.current_node])
	return array

func fetch_dir(pos: Vector2i) -> String:
	if pos.x == -1:
		return "EAST"
	if pos.x == width:
		return "WEST"
	if pos.y == -1:
		return "SOUTH"
	if pos.y == height:
		return "NORTH"
		
	return "NORTH"

func set_nav(w, h, i):
	var node = Map.map_nodes_array[i]
	
	if node.path_bottom:
		_process_edge_tile(true, h - 1, w, "DOWN")
		
	if node.path_top:
		_process_edge_tile(true, 0, w, "UP")
		
	if node.path_right:
		_process_edge_tile(false, w - 1, h, "RIGHT")
		
	if node.path_left:
		_process_edge_tile(false, 0, h, "LEFT")

func _process_edge_tile(is_horizontal: bool, fixed_coordinate: int, max_length: int, direction: String):
	var valid_positions: Array[Vector2i] = []
	
	for i in range(max_length):
		var pos = Vector2i(i, fixed_coordinate) if is_horizontal else Vector2i(fixed_coordinate, i)
		
		if not restricted_tiles.has(pos):
			valid_positions.append(pos)
			
	if not valid_positions.is_empty():
		var chosen_pos = valid_positions.pick_random()
		tilemap.set_cell(chosen_pos, 0, TILE[direction])
		nav_tiles[chosen_pos] = direction
	else:
		print_debug("Warning: No valid edge tiles available for direction: ", direction)

func _generate_new_board() -> void:
	counter.text = str(shards)
	HP.text = str(Global.health)
	Global.grid = create_board(width, height, shards)

func _restore_board(board: int) -> void:
	var saved = Map.map[board]
	var nav = saved["nav_tiles"]
	
	Global.grid = saved["grid"]
	
	for i in range(width):
		for j in range(height):
			tilemap.set_cell(Vector2i(i, j), 0, TILE["BLANK"])

	for tile in nav.keys():
		var direction_string = nav[tile]
		var dir_vector = TILE[direction_string]
		tilemap.set_cell(tile, 0, dir_vector)
		nav_tiles[tile] = direction_string

	for tile in saved["flagged_tiles"]:
		flagged_tiles[tile] = true
		tilemap.set_cell(tile, 0, TILE["FLAG"])

	for tile in saved["revealed_tiles"]:
		var cell_value = saved["revealed_tiles"][tile]
		revealed_tiles[tile] = cell_value
		if cell_value == 1:
			tilemap.set_cell(tile, 0, TILE["CORRECT"])
		elif cell_value == 0:
			tilemap.set_cell(tile, 0, TILE["WRONG"])
		else:
			get_nearby_bombs(Global.grid, tile)
			
	for item in saved["beasts"]:
		var beast = preload("res://bosses/beast.tscn").instantiate()
		
		beast.data = item.data
		beast.spawn_tile = item.position
		beast.dir = item.direction
		
		beast_container.add_child(beast)
		
	for item in saved["npcs"]:
		var npc = preload("res://npcs/npc.tscn").instantiate()
		
		npc.data = item.data
		npc.spawn_tile = item.position
		npc.dir = item.direction
		
		npc_container.add_child(npc)

	counter.text = str(saved["found"]) + "/" + str(shards)
	HP.text = str(Global.health)

func updateShards() -> void:
	var text = " "
	for key in Global.foundShards:
		text += str(key) + "\n"
		list.text = text

func get_nearby_bombs(grid: Array, tile: Vector2i):
	if is_travelling:
		return
		
	var surrounding = 0

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var check_x = tile.x + dx
			var check_y = tile.y + dy
			if check_x >= 0 and check_x < grid.size() and check_y >= 0 and check_y < grid[check_x].size():
				if grid[check_x][check_y] != 0:
					surrounding += 1

	if surrounding == 0:
		tilemap.set_cell(tile, 0, TILE["BLANK"])
	else:
		tilemap.set_cell(tile, 0, TILE[surrounding])

### Player Interactions

func _on_player_interacted(tile: Vector2) -> void:
	if is_travelling:
		return
		
	var tile_i := Vector2i(tile)
	print("Pressed Interact at: ", tile_i)
	
	var interactables = beast_container.get_children() + npc_container.get_children()
	
	for entity in interactables:
		if tile_i == entity.adjacent_tile:
			print("Interacted with ", entity.data.id)
			
			# 3. Route the data based on the entity's parent container
			if entity.get_parent() == beast_container:
				Global.current_beast = entity.data
				Pos.move(tile, "res://bosses/encounter.tscn")
			else:
				Global.current_npc = entity.data
				Pos.move(tile, "res://npcs/encounter.tscn")
			return
	
func _on_player_clicked(tile: Vector2) -> void:
	if is_travelling:
		return
		
	on_reveal(tile)

func _on_player_stepped(tile: Vector2) -> void:
	var tile_i = Vector2i(tile)
	
	if is_travelling:
		return
		
	if tile_i in nav_tiles or tile_i in revealed_tiles or tile_i in flagged_tiles or tile_i in restricted_tiles:
		return
	
	stepped_tiles[tile_i] = fade
	get_nearby_bombs(Global.grid, tile_i)

func _on_player_flagged(tile: Vector2) -> void:
	var tile_i = Vector2i(tile)
	
	if is_travelling:
		return

	if tile_i in revealed_tiles or tile_i in nav_tiles or tile_i in restricted_tiles:
		return

	if tile_i in flagged_tiles:
		flagged_tiles.erase(tile_i)
		tilemap.set_cell(tile_i, 0, TILE["BLANK"])
	else:
		flagged_tiles[tile_i] = true
		tilemap.set_cell(tile_i, 0, TILE["FLAG"])

	Map.map[Map.current_node]["flagged_tiles"] = flagged_tiles.keys()

func on_reveal(tile: Vector2):
	var tile_i = Vector2i(tile)
	
	if is_travelling:
		return
		
	if tile_i in restricted_tiles:
		return
	
	if tile_i in nav_tiles:
		var direction = nav_tiles[tile_i]
		print("Travelling ", direction)
		travel_to(tile_i)
		return

	check_shard(tile)
	
func check_shard(tile: Vector2):
	var tile_i = Vector2i(tile)
	
	if tile_i in flagged_tiles or tile_i in revealed_tiles:
		return
		
	print("Checking tile ", tile_i)
	var cell_value = Global.grid[tile_i.x][tile_i.y]
	revealed_tiles[tile_i] = cell_value

	if cell_value == 1:
		tilemap.set_cell(tile_i, 0, TILE["CORRECT"])
		found += 1
		counter.text = str(found) + "/" + str(shards)

		var keys = Global.lostShards.keys()
		var random_key = keys[randi_range(0, keys.size() - 1)]
		var key_shards = Global.lostShards.get(random_key)
		var shard = key_shards[randi_range(0, key_shards.size() - 1)]

		key_shards.erase(shard)
		if key_shards.is_empty():
			Global.lostShards.erase(random_key)

		if not Global.foundShards.has(random_key):
			Global.foundShards[random_key] = []
		Global.foundShards[random_key].append(shard)

		updateShards()
	else:
		tilemap.set_cell(tile_i, 0, TILE["WRONG"])
		Global.health -= 1
		if Global.health <= 0:
			lose()

	HP.text = str(Global.health)

	# Save tile state back to global map.
	Map.map[Map.current_node]["revealed_tiles"] = revealed_tiles.duplicate()
	Map.map[Map.current_node]["found"] = found

### Helpers
func lose() -> void:
	get_tree().paused = true

func _process(delta: float) -> void:
	for tile in stepped_tiles.keys():
		stepped_tiles[tile] -= delta

		if stepped_tiles[tile] <= 0 and tile not in revealed_tiles and tile not in flagged_tiles:
			stepped_tiles.erase(tile)
			tilemap.set_cell(tile, 0, TILE["BLANK"])

func center_camera() -> void:
	var center: Vector2 = Vector2(Global.TILE_SIZE * width / 2, Global.TILE_SIZE * height / 2)
	camera.global_position = center
	$"2675758ShippukirifudaWipTopDownDesert".global_position = center

func travel_to(tile: Vector2i) -> void:
	if is_travelling:
		return 
		
	is_travelling = true
	
	Map.map[Map.current_node]["flagged_tiles"] = flagged_tiles.keys()
	Map.map[Map.current_node]["revealed_tiles"] = revealed_tiles.duplicate()
	Map.map[Map.current_node]["nav_tiles"] = nav_tiles.duplicate()
	Map.map[Map.current_node]["found"] = found
	Map.map[Map.current_node]["npc"] = npcs
	Map.map[Map.current_node]["beasts"] = beasts
	
	var grid_width = Map.map_width 
	var dir: String
	
	if tile.y == 0:
		Map.current_node -= grid_width
		dir = "NORTH"
	elif tile.y == height - 1:
		Map.current_node += grid_width
		dir = "SOUTH"
	elif tile.x == 0:
		Map.current_node -= 1
		dir = "WEST"
	elif tile.x == width - 1:
		Map.current_node += 1
		dir = "EAST"
	
	Pos.temp_i = Pos.on_new_board(tile, dir, height, width)
	print("Player travelled from tile: ", tile, " to tile: ", Pos.temp_i)
	
	Global.grid = []
	found = 0
	revealed_tiles.clear()
	flagged_tiles.clear()
	stepped_tiles.clear()
	nav_tiles.clear()
	
	get_tree().reload_current_scene()
	
func _ready() -> void:
	
	shards = Map.get_room_data("shards")
	center_camera()
	Pos.set_player(Player.STEP, Player)
	
	## Clear all things
	for item in beast_container.get_children():
		item.queue_free()
		
	for item in npc_container.get_children():
		item.queue_free()
	
	if Map.map_grid.is_empty():
		Map.generate(Map.map_width, Map.map_height)
		
	if Map.current_node not in Map.discovered_nodes:
		Map.discovered_nodes.append(Map.current_node)
		
	if Map.map.has(Map.current_node):
		_restore_board(Map.current_node)
		print("\nNode ", Map.current_node, " found, restoring board...\n")
	else:
		_generate_new_board()
		print("\nCouldn't find Node ", Map.current_node, "! Creating new board...\n")
	
	for item in npc_container.get_children():
		print(item.data.id, " - Reference: ", item.adjacent_tile)
	for item in beast_container.get_children():
		print(item.data.id, " - Reference: ", item.adjacent_tile)
		
	#print(Map.map)

func _on_button_pressed() -> void:
	Pos.move(Player.global_position, "res://jigsaw/assembly.tscn")
