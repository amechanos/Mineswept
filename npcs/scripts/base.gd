extends Resource

class_name NpcData

enum {NORTH, EAST, SOUTH, WEST}

@export var id: String = ""
@export var name: String = ""
@export var texture: Texture2D
@export var dialogue: Array[String]
@export var choices: Dictionary # { "options": [], "index": 4 }
@export var direction = NORTH

var choice_memory = []
var is_npc = true
