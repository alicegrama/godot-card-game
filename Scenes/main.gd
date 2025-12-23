extends Node2D

@onready var playerhand = $PlayerHand

@onready var opponenthand = $OpponentHand
@onready var cardslot = $CardSlot

var playablecards = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	start_game()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func playable(hand):
	var prevcard = cardslot.card
	if prevcard == null:
		return hand
	var arr = []
	print(prevcard.suit)
	for i in hand:
		print(i.suit)
		if i.suit == prevcard.suit or i.number == prevcard.number:
			arr.append(i)
	print(arr)
	return arr
	
func player_turn():
	playablecards = playable(playerhand.hand)
	$CardManager.interaction = true

func opponent_turn():
	$CardManager.interaction = false
	await get_tree().create_timer(1.0).timeout
	var card = playable(opponenthand.hand).pick_random()
	if card == null:
		#draw a card
		card = $CardManager.draw_deck(opponenthand)
		card.toggle()
		
	else:
		card.toggle()
		$CardManager.place_card(card, opponenthand)
	player_turn()
	

func start_game():
	player_turn()
	pass
