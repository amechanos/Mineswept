extends CharacterBody2D

signal stepped(tile: Vector2)
signal revealed(tile: Vector2)
signal flagged(tile: Vector2, state: bool)

const STEP = 56
const MAX_LIMIT = STEP * Global.WIDTH
const MIN_LIMIT = 0

func _input(event):
	var move_dir = Vector2.ZERO
	
	# Standard WASD / Arrow movement checks
	if event.is_action_pressed("ui_up"): move_dir.y = -1
	elif event.is_action_pressed("ui_down"): move_dir.y = 1
	elif event.is_action_pressed("ui_left"): move_dir.x = -1
	elif event.is_action_pressed("ui_right"): move_dir.x = 1
	
	elif event.is_action_pressed("ui_accept"): revealed.emit(get_tile(position)) # Spacebar / LMB
	elif event.is_action_pressed("ui_alt"): flagged.emit(get_tile(position)) # Control / RMB

	if move_dir != Vector2.ZERO:
		var target_pos = position + (move_dir * STEP)
		
		if is_within_bounds(target_pos):
			stepped.emit(get_tile(position))
			position = target_pos

func is_within_bounds(pos: Vector2) -> bool:
	return pos.x >= MIN_LIMIT and pos.x <= MAX_LIMIT and \
		   pos.y >= MIN_LIMIT and pos.y <= MAX_LIMIT
		
func get_tile(position: Vector2) -> Vector2:
	var x = (position.x - STEP/2) / STEP
	var y = (position.y - STEP/2) / STEP
	return Vector2(x,y)
