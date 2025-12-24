extends Node2D

signal hovered
signal hovered_off

var suit = "h"
var number = 3
var starting_position

var carddata = {
	"h" : {1 : preload("res://Assets/cards/h_1.png"), 2: preload("res://Assets/cards/h_2.png"),
			3 : preload("res://Assets/cards/h_3.png"), 4: preload("res://Assets/cards/h_4.png"),
			5 : preload("res://Assets/cards/h_5.png"), 6: preload("res://Assets/cards/h_6.png"),
			7 : preload("res://Assets/cards/h_7.png"), 8: preload("res://Assets/cards/h_8.png"),
			9 : preload("res://Assets/cards/h_9.png"), 10: preload("res://Assets/cards/h_10.png"),
			11 : preload("res://Assets/cards/h_11.png"), 12: preload("res://Assets/cards/h_12.png"),
			13 : preload("res://Assets/cards/h_13.png")},
	"c" : {1 : preload("res://Assets/cards/c_1.png"), 2: preload("res://Assets/cards/c_2.png"),
			3 : preload("res://Assets/cards/c_3.png"), 4: preload("res://Assets/cards/c_4.png"),
			5 : preload("res://Assets/cards/c_5.png"), 6: preload("res://Assets/cards/c_6.png"),
			7 : preload("res://Assets/cards/c_7.png"), 8: preload("res://Assets/cards/c_8.png"),
			9 : preload("res://Assets/cards/c_9.png"), 10: preload("res://Assets/cards/c_10.png"),
			11 : preload("res://Assets/cards/c_11.png"), 12: preload("res://Assets/cards/c_12.png"),
			13 : preload("res://Assets/cards/c_13.png")},
	"d" : {1 : preload("res://Assets/cards/d_1.png"), 2: preload("res://Assets/cards/d_2.png"),
			3 : preload("res://Assets/cards/d_3.png"), 4: preload("res://Assets/cards/d_4.png"),
			5 : preload("res://Assets/cards/d_5.png"), 6: preload("res://Assets/cards/d_6.png"),
			7 : preload("res://Assets/cards/d_7.png"), 8: preload("res://Assets/cards/d_8.png"),
			9 : preload("res://Assets/cards/d_9.png"), 10: preload("res://Assets/cards/d_10.png"),
			11 : preload("res://Assets/cards/d_11.png"), 12: preload("res://Assets/cards/d_12.png"),
			13 : preload("res://Assets/cards/d_13.png")},
	"s" : {1 : preload("res://Assets/cards/s_1.png"), 2: preload("res://Assets/cards/s_2.png"),
			3 : preload("res://Assets/cards/s_3.png"), 4: preload("res://Assets/cards/s_4.png"),
			5 : preload("res://Assets/cards/s_5.png"), 6: preload("res://Assets/cards/s_6.png"),
			7 : preload("res://Assets/cards/s_7.png"), 8: preload("res://Assets/cards/s_8.png"),
			9 : preload("res://Assets/cards/s_9.png"), 10: preload("res://Assets/cards/s_10.png"),
			11 : preload("res://Assets/cards/s_11.png"), 12: preload("res://Assets/cards/s_12.png"),
			13 : preload("res://Assets/cards/s_13.png")}
}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#All cards must be a child of CardManager or this will error
	get_parent().connect_card_signals(self)
	
func setup(s, n):
	#give the card its suit and number
	suit = s
	number = n
	$CardImage.texture = carddata[s][n]

func get_suit_number():
	return [suit, number]

func _on_area_2d_mouse_entered() -> void:
	emit_signal("hovered", self)


func _on_area_2d_mouse_exited() -> void:
	emit_signal("hovered_off", self)
	
func toggle():
	#hides the card or lets them show.
	$CardImageBack.visible = !$CardImageBack.visible
	
func all_off():
	#remove all buttons of the card
	toggle_give(false)
	toggle_take(false)
	toggle_look(false)
		
func toggle_take(visible):
	$Take.visible = visible
	
func toggle_give(visible):
	$Give.visible = visible
	
func toggle_look(visible):
	$Look.visible = visible
	
func _on_take_pressed() -> void:
	$"..".take($".", 1)

func _on_give_pressed() -> void:
	$"..".take($".", 0)


func _on_look_pressed() -> void:
	toggle()
	await get_tree().create_timer(2.0).timeout
	toggle()
	$"../".looked()
	
func move_forward():
	position.y -= 50
