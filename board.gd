extends Node2D

@onready var tilemap = $TileMapLayer
@onready var Player = $player
@onready var HP = $Health/Value

var revealed_tiles = {}
var flagged_tiles = {}

const TILE = {
	"BLANK": Vector2i(0,0),
	"CORRECT": Vector2i(1,0), # Player
	"WRONG": Vector2i(2,0), # Enemy
	"FLAG": Vector2i(0,4),
	1: Vector2i(1,1),
	2: Vector2i(2,1),
	3: Vector2i(0,2),
	4: Vector2i(1,2),
	5: Vector2i(2,2),
	6: Vector2i(0,3),
	7: Vector2i(1,3),
	8: Vector2i(2,3)
}

func create_board(w: int, h: int, player_attacks: int) -> Array:
	# Fill with empty
	var array = []
	for i in range(w):
		array.append([])
		for j in range(h):
			tilemap.set_cell(Vector2i(i, j), 0, TILE["BLANK"])
			array[i].append(0)
	
	var positions = []
	for i in range(w):
		for j in range(h):
			positions.append(Vector2i(i, j))
	positions.shuffle()
	
	for k in range(player_attacks):
		var pos = positions[k]
		array[pos.x][pos.y] = 1
	
	return array

func get_nearby_bombs(grid: Array, tile: Vector2i):
	var surrounding = 0

	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
				
			var check_x = tile.x + dx
			var check_y = tile.y + dy

			if check_x >= 0 and check_x < Global.WIDTH and check_y >= 0 and check_y < Global.HEIGHT:
				if Global.grid[check_x][check_y] != 0:
					surrounding += 1

	if surrounding == 0:
		tilemap.set_cell(tile, 0, TILE["BLANK"])
	else:
		tilemap.set_cell(tile, 0, TILE[surrounding])

func _on_player_revealed(tile: Vector2) -> void:
	var tile_i = Vector2i(tile)
	if tile_i in flagged_tiles or tile_i in revealed_tiles:
		return
	
	revealed_tiles[tile_i] = true
	var cell_value = Global.grid[tile_i.x][tile_i.y]
	
	if cell_value == 1:  # player attack
		tilemap.set_cell(tile_i, 0, TILE["CORRECT"])
		Global.attacksFound += 1
		if Global.attacksFound >= Global.ATTACKS:
			win()
	else:  # enemy attack
		tilemap.set_cell(tile_i, 0, TILE["WRONG"])
		Global.health -= 1
		print("Health: ", Global.health)
		if Global.health <= 0:
			lose()
			
	HP.text = str(Global.health)

func win() -> void:
	print("You win!")
	get_tree().paused = true

func lose() -> void:
	print("You lose!")
	get_tree().paused = true

func _on_player_stepped(tile: Vector2) -> void:
	var tile_i = Vector2i(tile)
	if tile_i in revealed_tiles or tile_i in flagged_tiles:
		return
	get_nearby_bombs(Global.grid, tile_i)

func _on_player_flagged(tile: Vector2) -> void:
	var tile_i = Vector2i(tile)
	
	if tile_i in revealed_tiles:
		return
	
	if tile_i in flagged_tiles:
		flagged_tiles.erase(tile_i)
		tilemap.set_cell(tile_i, 0, TILE["BLANK"])  # unflag
	else:
		flagged_tiles[tile_i] = true
		tilemap.set_cell(tile_i, 0, TILE["FLAG"])
		
func _ready() -> void:
	Global.grid = create_board(Global.WIDTH, Global.HEIGHT, Global.ATTACKS)
	Player.global_position = Vector2(Player.STEP/2, Player.STEP/2)
	HP.text = str(Global.health)
