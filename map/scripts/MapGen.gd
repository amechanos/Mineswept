extends Node

var current_node = 1
var map: Dictionary = {}
var map_grid: Dictionary = {}
var map_nodes_array: Array[MapCell] = []
var discovered_nodes: Array = []
var spawn_ref = {} # NEW {"node-1": {"beasts": x, "npcs": y, "shards": z}}

var beast_pool = Array(DirAccess.get_files_at("res://bosses/beasts/"))
var npc_pool = Array(DirAccess.get_files_at("res://npcs/npc/"))
var map_width = 9
var map_height = 8

func get_room_data(data_type: String, room = current_node):
	var room_key = "node-" + str(room)
	if spawn_ref.has(room_key) and spawn_ref[room_key].has(data_type):
		return spawn_ref[room_key][data_type]
	return null

func get_valid_positions(w, h):
	var valid_pos = []
	
	for i in range(w):
		valid_pos.append(Vector2i(i, -1))
		valid_pos.append(Vector2i(i, h+1))
		
	for i in range(h):
		valid_pos.append(Vector2i(-1, i))
		valid_pos.append(Vector2i(w, i))
	
	return valid_pos
	
func set_refs(rooms):
	# Shards
	var card_size = Loader.DEFAULT_COLS * Loader.DEFAULT_ROWS
	var remaining = card_size * 22
	var temp_shards = 0
	
	# Setup
	var remaining_beasts = 22
	var remaining_npcs = 1
	
	for i in range(1, rooms):
		var rooms_left = (rooms - i) + 1

		# --- SHARDS (Kept as an integer count) ---
		var dynamic_avg = float(remaining) / rooms_left
		var amount = randi_range(round(dynamic_avg) - 2, round(dynamic_avg) + 2)
		amount = clamp(amount, 0, remaining)
		
		# --- ROOM POSITIONS SETUP ---
		# Fetch the master list of available tiles for this room layout
		var available_tiles = get_valid_positions(8, 6)
		
		var npc_positions: Array[Vector2i] = []
		var beast_positions: Array[Vector2i] = []

		# --- NPCs SCATTERING ---
		var npc_amount = 0
		
		# 1. Check chance for a pack to spawn
		if remaining_npcs > 0 and randf() < 1:
			var dynamic_beast_avg = float(remaining_npcs) / rooms_left
			npc_amount = 1
		
		# 2. Late-game guardrail to bleed the npc pool
		if rooms_left <= 3 and remaining_npcs > 0 and npc_amount == 0:
			npc_amount = randi_range(1, remaining_npcs)
			
		# 3. Physically pick coordinates from the leftover tiles
		if npc_amount > 0 and available_tiles.size() > 0:
			for k in range(npc_amount):
				if available_tiles.is_empty(): break # Safe-guard if layout is totally packed
				
				var random_pos = available_tiles.pick_random()
				npc_positions.append(random_pos)
				available_tiles.erase(random_pos) # Prevent npcs from overlapping each other

		# --- BEASTS SCATTERING ---
		var beast_amount = 0
		
		# 1. Check chance for a pack to spawn
		if remaining_beasts > 0 and randf() < 1:
			var dynamic_beast_avg = float(remaining_beasts) / rooms_left
			beast_amount = 1
		
		# 2. Late-game guardrail to bleed the beast pool
		if rooms_left <= 3 and remaining_beasts > 0 and beast_amount == 0:
			beast_amount = randi_range(1, remaining_beasts)
			
		# 3. Physically pick coordinates from the leftover tiles
		if beast_amount > 0 and available_tiles.size() > 0:
			for k in range(beast_amount):
				if available_tiles.is_empty(): break # Safe-guard if layout is totally packed
				
				var random_pos = available_tiles.pick_random()
				beast_positions.append(random_pos)
				available_tiles.erase(random_pos) # Prevent beasts from overlapping each other
		
		# --- RECORD DATA ---
		var node_key = "node-" + str(i)
		# Now storing the dynamic array of Vector2i positions for BOTH entities
		spawn_ref[node_key] = {
			"beasts": beast_positions, 
			"npcs": npc_positions, 
			"shards": amount
		}
		
		# --- UPDATE POOLS ---
		remaining -= amount
		temp_shards += amount
		remaining_npcs -= npc_positions.size()
		remaining_beasts -= beast_positions.size() # Reduce pool by actual spawned amount
		
	# --- LAST ROOM ---
	# Last room consumes all remaining shards and beasts
	var last_node_key = "node-" + str(rooms)
	var final_tiles = get_valid_positions(8, 6)
	var final_beast_positions: Array[Vector2i] = []
	
	if remaining_beasts > 0 and final_tiles.size() > 0:
		for b in range(remaining_beasts):
			if final_tiles.is_empty(): break
			var random_pos = final_tiles.pick_random()
			final_beast_positions.append(random_pos)
			final_tiles.erase(random_pos)

	spawn_ref[last_node_key] = {
		"beasts": final_beast_positions, 
		"npcs": [] as Array[Vector2i], 
		"shards": remaining
	}

func _ready() -> void:
	set_refs(map_width*map_height)
	#print("Created game!\n", spawn_ref) 
	
	npc_pool.shuffle()
	beast_pool.shuffle()
		
# --- Union-Find for spanning tree ---
class UnionFind:
	var parent: Array[int]
	var rank: Array[int]
	
	func _init(size: int):
		parent.resize(size)
		rank.resize(size)
		for i in range(size):
			parent[i] = i
			rank[i] = 0
	
	func find(x: int) -> int:
		if parent[x] != x:
			parent[x] = find(parent[x])
		return parent[x]
	
	func union(x: int, y: int) -> void:
		var rx = find(x)
		var ry = find(y)
		if rx == ry:
			return
		if rank[rx] < rank[ry]:
			parent[rx] = ry
		elif rank[rx] > rank[ry]:
			parent[ry] = rx
		else:
			parent[ry] = rx
			rank[rx] += 1

func generate(w: int, h: int) -> void:
	map_grid.clear()
	map_nodes_array.clear()
	map_width = w
	map_height = h
	
	# 1. Initialize all cells
	for y in range(h):
		for x in range(w):
			var cell = MapCell.new(Vector2(x, y))
			map_grid[Vector2(x, y)] = cell
			map_nodes_array.append(cell)
	
	# Edge case: 1x1 map can't have any connections
	if w == 1 and h == 1:
		return
	
	# 2. Collect all possible edges
	var edges: Array[Dictionary] = []
	for y in range(h):
		for x in range(w):
			if x < w - 1:
				edges.append({"from": Vector2(x, y), "to": Vector2(x + 1, y), "type": "H"})
			if y < h - 1:
				edges.append({"from": Vector2(x, y), "to": Vector2(x, y + 1), "type": "V"})
	
	# 3. Randomize
	edges.shuffle()
	
	# 4. Build spanning tree
	var uf = UnionFind.new(w * h)
	var tree_edges: Array[Dictionary] = []
	var remaining_edges: Array[Dictionary] = []
	
	for edge in edges:
		var from_idx = edge.from.y * w + edge.from.x
		var to_idx = edge.to.y * w + edge.to.x
		
		if uf.find(from_idx) != uf.find(to_idx):
			uf.union(from_idx, to_idx)
			tree_edges.append(edge)
		else:
			remaining_edges.append(edge)
	
	# 5. Add sparse extra edges for loops / variety
	# Lower = more maze-like, Higher = more grid-like. 0.12–0.18 is a sweet spot.
	var extra_connection_chance: float = 0.15
	for edge in remaining_edges:
		if randf() < extra_connection_chance:
			tree_edges.append(edge)
	
	# 6. Apply to cells (bidirectional)
	for edge in tree_edges:
		var a: MapCell = map_grid[edge.from]
		var b: MapCell = map_grid[edge.to]
		if edge.type == "H":
			a.path_right = true
			b.path_left = true
		else:
			a.path_bottom = true
			b.path_top = true
