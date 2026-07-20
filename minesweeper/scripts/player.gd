extends CharacterBody2D

signal stepped(tile: Vector2)
signal flagged(tile: Vector2, state: bool)
signal moved(tile: Vector2)
signal interacted(tile: Vector2)
signal clicked(tile: Vector2)
signal travelled()

@onready var image = $Texture

const STEP = Global.TILE_SIZE

const textures = {
	"NORTH": "res://minesweeper/assets/P_NORTH.png",
	"EAST": "res://minesweeper/assets/P_EAST.png",
	"SOUTH": "res://minesweeper/assets/P_SOUTH.png",
	"WEST": "res://minesweeper/assets/P_WEST.png",
}

var MAX_X = 0
var MAX_Y = 0
var MIN_LIMIT = 0
var multiplier = 1

var target_pos = position
var travel = false

func _ready() -> void:
	# Use separate limits for width and height
	MAX_X = STEP * get_parent().width
	MAX_Y = STEP * get_parent().height

func _unhandled_input(event: InputEvent) -> void:
	var move_dir = Vector2.ZERO
	
	if event.is_action_pressed("ui_up"): 
		move_dir.y = -1
		image.texture = load(textures["NORTH"])
	elif event.is_action_pressed("ui_down"): 
		move_dir.y = 1
		image.texture = load(textures["SOUTH"])
	elif event.is_action_pressed("ui_left"): 
		move_dir.x = -1
		image.texture = load(textures["WEST"])
	elif event.is_action_pressed("ui_right"): 
		move_dir.x = 1
		image.texture = load(textures["EAST"])
	
	elif event.is_action_pressed("interact"): interacted.emit(get_tile(position))
	elif event.is_action_pressed("ui_accept"): clicked.emit(get_tile(position))
	elif event.is_action_pressed("ui_alt"): flagged.emit(get_tile(position))

	if move_dir != Vector2.ZERO:
		target_pos = position + (move_dir * STEP)
		moved.emit(get_tile(target_pos))
		
		if is_within_bounds(target_pos):
			stepped.emit(get_tile(position))
			position = target_pos

func is_within_bounds(pos: Vector2) -> bool:
	return pos.x >= MIN_LIMIT and pos.x <= MAX_X and \
		   pos.y >= MIN_LIMIT and pos.y <= MAX_Y
		
func get_tile(position: Vector2) -> Vector2:
	var x = (position.x - STEP/2) / STEP
	var y = (position.y - STEP/2) / STEP
	return Vector2(x, y)
