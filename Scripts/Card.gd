extends Node2D

signal hovered
signal hovered_off

var starting_position

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#All cards must be a child of CardManager or this will error
	get_parent().connect_card_signals(self)

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
	
func toggle():
	#hides the card or lets them show.
	$CardImageBack.visible = !$CardImageBack.visible
		
