extends Node2D

var card_in_slot = false

var card = null

func add_card_to_hand(id, speed):
	#So I can put a card here
	card = id
	card.position = $".".position
