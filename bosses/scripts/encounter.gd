extends Control

@onready var container = $Holder/CardDisplay
@onready var warning = $Warning
@onready var sprite = $Image
@onready var title = $Name
@onready var textbox = $Dialogue
@onready var next = $Next

@export var active: Resource # The active beast or NPC

var beast_default = load("res://bosses/textures/SOUTH.png")
var scene

var riddle: int
var index: int = 0
var affected: bool = false

var dialogue: Array = []

func _ready() -> void:
	
	active = Global.current_beast
	
	affected = false
	if Global.riddle_ref.has(active.id):
		riddle = Global.riddle_ref[active.id]
	else:
		riddle = randi_range(0, active.riddle_texts.size() - 1)
		Global.riddle_ref[active.id] = riddle
		
	scene = get_tree().current_scene
	sprite.texture = beast_default
	setup()
	set_dialogue()

func set_dialogue():
	dialogue = [
		"You approach the weathered statue and gently dust of the debris around.",
		"Removing the debris, you find some symbols near the base.",
		"You recognise the symbols forming a riddle and it reads: ",
		active.riddle_texts[riddle],
		"You notice a small slit near the top, perhaps giving the statue an offering may awaken it?"
	]
	
	title.text = "???"
	textbox.text = dialogue[index]
	index += 1
	
func setup():
	for card in Global.completedCards:
		print(card)
		var tarot = preload("res://ui/card.tscn").instantiate()
		var path = "res://tarot/cards/" + card + ".png"
		tarot.id = card
		tarot.custom_minimum_size = Vector2(196, 75)
		tarot.texture = load(path)
		container.add_child(tarot)
		tarot.connect("sent", giveCard)
	
	if container.get_children().is_empty():
		warning.visible = true
		
func giveCard(card: String, reversed: bool):
	next.visible = false
	if card.to_lower() == active.correct_card:
		textbox.text = active.upright_outcome if not reversed else active.reversed_outcome
		affected = true
	else:
		textbox.text = active.rejection_hint
		await get_tree().create_timer(5).timeout
		if scene == get_tree().current_scene:
			textbox.text = active.riddle_texts[Global.riddle_ref[active.id]]

func _on_leave_pressed() -> void:
	Global.current_beast = null
	Pos.return_from(affected, "res://minesweeper/board.tscn")

func _on_next_pressed() -> void:
	textbox.text = dialogue[index]
	if index < dialogue.size()-1:
		index += 1
	
