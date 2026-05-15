extends Node

# Minesweeper Mode 
var grid: Array = []

var health: int = 10

# Jigsaw Mode
const max_pieces = 8
const min_pieces = 8

var shardLibrary: Dictionary = {}

func _ready():
	Loader.load_shard_library()
