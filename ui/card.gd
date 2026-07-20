extends Control

signal sent(card: String, reversed: bool)

@export var texture: Texture2D

@onready var tooltip = $Panel
@onready var title = $Panel/Name
@onready var image = $Texture

var tween: Tween
var entered: bool = false

var reversed: bool = false
var id: String

func _ready():
	title.text = id.replace("_", " ").capitalize()
	image.texture = texture
	tooltip.visible = false

func _on_mouse_entered():
	entered = true
	tooltip.visible = true

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.15)

func _on_mouse_exited():
	tooltip.visible = false
	entered = false

	if tween:
		tween.kill()

	tween = create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "scale", Vector2.ONE, 0.15)
	
func _input(event: InputEvent) -> void:
	if not entered:
		return
	
	if event.is_action_pressed("rotateCC"):
		image.flip_h = !image.flip_h
		image.flip_v = !image.flip_v
		reversed = !reversed
		if reversed:
			title.text += " (Reversed)"
		else:
			title.text = title.text.replace(" (Reversed)", "")
	
	if event.is_action_pressed("ui_accept"):
		sent.emit(id, reversed)
		print("Card submitted!")
