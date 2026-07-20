extends Control

@onready var sprite = $Image
@onready var title = $Name
@onready var textbox = $Dialogue
@onready var next = $Next

@export var active: Resource # The active beast or NPC

var scene

var dialogue: Array = []
var index: int = 0

func _ready() -> void:
	active = Global.current_npc
	var dir = "res://npcs/textures/%s/SOUTH.png" % active.id
	print("Loading ", dir)
	sprite.texture = load(dir)
	title.text = active.name
	dialogue = active.dialogue
	textbox.text = dialogue[index]
	index += 1

func _on_leave_pressed() -> void:
	Global.current_npc = null
	Pos.return_from(false, "res://minesweeper/board.tscn")

func _on_next_pressed() -> void:
	textbox.text = dialogue[index]
	if index < dialogue.size()-1:
		index += 1
