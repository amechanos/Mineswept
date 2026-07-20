class_name Beast
extends Control

@export var data: BeastData
@export var spawn_tile: Vector2i
@export var dir: String

@onready var image = $TextureRect
@onready var prompt_label = $Panel

var adjacent_tile: Vector2i

var board
var display_tile

func _ready() -> void:
	board = get_parent().get_parent()
	image.z_index = max(10, spawn_tile.y * 10)
	
	var path = "res://bosses/textures/%s.png" % dir
	print(path)
	image.texture = load(path)
	
	global_position = Vector2((spawn_tile.x * Global.TILE_SIZE), (spawn_tile.y * Global.TILE_SIZE))
	if spawn_tile.y == Global.HEIGHT + 1:
		image.position.y -= Global.TILE_SIZE * 0.5
	print("Position set to: ", global_position)
	
	match dir.to_upper().strip_edges():
		"NORTH":
			adjacent_tile = spawn_tile + Vector2i(0, -2)
		"EAST":
			adjacent_tile = spawn_tile + Vector2i(1, 0)
		"SOUTH":
			adjacent_tile = spawn_tile + Vector2i(0, 1)
		"WEST":
			adjacent_tile = spawn_tile + Vector2i(-1, 0)
		_:
			adjacent_tile = spawn_tile + Vector2i(0, 0)
	
	prompt_label.global_position = Vector2((adjacent_tile.x * Global.TILE_SIZE) + 16, (adjacent_tile.y * Global.TILE_SIZE) + 16)
	print("Setting prompt to ", adjacent_tile, ". Globalised: ", prompt_label.global_position)
	
	if data == null:
		return

	if Global.defeated_beasts.has(data.id):
		visible = false
		return
	
	print("Adjacent Tile: ", adjacent_tile)
