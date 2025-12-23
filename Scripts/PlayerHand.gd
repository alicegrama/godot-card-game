extends Node2D

const CARD_WIDTH = 200
const HAND_Y_POSITION = 0
const UPDATE_CARD_POS_SPEED = 0.1
const CARD_SCENE_PATH = "res://Scenes/card.tscn"
const DRAW_SPEED = 0.2
const HAND_COUNT = 5
const CARD_SPACING = CARD_WIDTH + 40

var hand = [] # array of card names
var card_manager


func _ready():
	card_manager = get_parent().get_node("CardManager")
	var card_scene = preload(CARD_SCENE_PATH)
	for i in range(HAND_COUNT):
		var new_card = card_scene.instantiate() as Node2D
		$"../CardManager".draw_deck($".")

# called when player stops dragging a card, and when new card drawn from deck
func add_card_to_hand(card, speed_to_move):
	# if card drawn from deck
	if card not in hand:
		hand.insert(0, card)
		update_hand_positions(speed_to_move)
	else:
		animate_card_to_position(card, card.starting_position, speed_to_move)


# updates positions of all cards in the hand
func update_hand_positions(speed):
	for i in range(hand.size()):
		var new_position = calculate_card_position(i)
		var card = hand[i]
		card.starting_position = new_position
		animate_card_to_position(card, new_position, speed)


# calculates the position for a card based on its index in the hand
func calculate_card_position(index):
	var center_screen_x = get_viewport().size.x / 2
	var total_width = (hand.size() - 1) * CARD_SPACING
	var x_offset = center_screen_x + index * CARD_SPACING - total_width / 2
	return Vector2(x_offset, HAND_Y_POSITION + $".".position[1])


# animates a card to a target position using a tween
func animate_card_to_position(card, new_position, speed_to_move):
	var tween = get_tree().create_tween()
	tween.tween_property(card, "position", new_position, speed_to_move)


# removes a card from the hand and updates remaining card positions
func remove_card_from_hand(card_name):
	# get the card node from the CardManager
	var card = card_manager.get_node(str(card_name))
	if card in hand:
		hand.erase(card)
		update_hand_positions(UPDATE_CARD_POS_SPEED)
