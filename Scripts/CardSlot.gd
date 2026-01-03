"""Keeps track of the card on the table, the discard pile."""
extends Node2D

var card_in_slot = false

var card = null

func add_card_to_hand(id, speed):
	"""Put a card at the middle of the table."""
	card = id
	card.position = $".".position
