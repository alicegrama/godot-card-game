extends Node2D

const COLLISION_MASK_CARD = 1
const COLLISION_MASK_CARD_SLOT = 2
const RETURN_TO_HAND_SPEED = 0.15
const CARD_SCENE_PATH = "res://Scenes/card.tscn"

var card_being_dragged
var screen_size
var is_hovering_on_card
var player_hand_reference
var opponent_hand_reference

var deck = []
var interaction = false

func _ready() -> void:
	screen_size = get_viewport_rect().size
	player_hand_reference = $"../PlayerHand"
	opponent_hand_reference = $"../OpponentHand"
	
	for i in range(1, 14):
		for j in ["h", "c", "d", "s"]:
			deck.append([j, i])
	
func draw_deck(hand):
	#draw a card from the deck returns the card
	if not deck:
		return
		
	var sn = deck.pick_random()
	deck.erase(sn)
	
	var card_scene = preload(CARD_SCENE_PATH)
	var new_card = card_scene.instantiate() as Node2D
	new_card.setup(sn[0], sn[1])
	new_card.position = $"../Deck".position
	$".".add_child(new_card)
	new_card.name = "Card"
	hand.add_card_to_hand(new_card, 0.1)
	if hand == opponent_hand_reference:
		new_card.toggle()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if card_being_dragged:
		var mouse_pos = get_global_mouse_position()
		card_being_dragged.position = Vector2(clamp(mouse_pos.x, 0, screen_size.x),
			 clamp(mouse_pos.y, 0, screen_size.y))

func _input(event):
	if !interaction:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var card = raycast_check_for_card()
			if card == null or !interaction:
				return
			if card in player_hand_reference.hand:
				if $"..".state == "points":
					place_card(card, player_hand_reference)
					draw_deck(player_hand_reference)
					#add card to history
					$"..".history.append([card.suit, card.number])
					$"..".turn_finished.emit()
					return
				#check if action allowed
				if (($"..".state == "uno" and $"..".playerstate == "card")):
					if card not in $"..".playablecards:
						$"..".change_rules(card.number, card.suit, $"../CardSlot".card.number, $"../CardSlot".card.suit)
					place_card(card, player_hand_reference)
					if len(player_hand_reference.hand) == 0:
						#game is over
						print("winning streak")
						$"..".end_game()
						return
					#if it has no rule add a rule?
					if $"..".rules[[card.suit,card.number]] == null or $"..".rules[[card.suit,card.number]] == 0:
						$"..".toggle_actions(true)
					else:
						$"..".take_action(card.suit, card.number, 1)
			elif card == $"../CardSlot" and $"../CardSlot".card == null and $"..".state == "setup":
				draw_deck($"../CardSlot")
				$"..".opponentsetup()
		else:
			if card_being_dragged:
				pass
				#finish_drag()
				
func place_card(id, hand):
	#places card the discard place
	hand.animate_card_to_position(id, $"../CardSlot".position, 0.1)
	hand.remove_card_from_hand(id)
	id.all_off()
	if $"../CardSlot".card != null:
		await get_tree().create_timer(0.06).timeout
		deck.append([$"../CardSlot".card.suit, $"../CardSlot".card.number])
		$"../CardSlot".card.queue_free()
		#make the id card move to the background
	$"../CardSlot".card = id

func start_drag(card):
	card_being_dragged = card
	card.scale = Vector2(1, 1)

func finish_drag():
	print("Running")
	card_being_dragged.scale = Vector2(1.05, 1.05)
	var card_slot_found = raycast_check_for_card_slot()
	if card_slot_found and not card_slot_found.card_in_slot:
		player_hand_reference.remove_card_from_hand(card_being_dragged)
		# Card dropped in empty slot
		card_being_dragged.position = card_slot_found.position
		card_being_dragged.get_node("Area2D/CollisionShape2D").disabled = true
		card_slot_found.card_in_slot = true
	else:
		player_hand_reference.add_card_to_hand(card_being_dragged,RETURN_TO_HAND_SPEED )
	card_being_dragged = null

func connect_card_signals(card):
	card.connect("hovered", on_hovered_over_card)
	card.connect("hovered_off", on_hovered_off_card)
	
func on_hovered_over_card(card):
	if !is_hovering_on_card:
		is_hovering_on_card = true
		highlight_card(card,  true)
	
func on_hovered_off_card(card):
	if !card_being_dragged:
		# if not dragging
		highlight_card(card,  false)
	# check if hovered off card straight into another card
	var new_card_hovered = raycast_check_for_card()
	if new_card_hovered:
		highlight_card(new_card_hovered, true)
	else: 
		is_hovering_on_card = false
	

func highlight_card(card, hovered):
	if hovered:
		card.scale = Vector2(1.05, 1.05)
		card.z_index = 2
	else:
		card.scale = Vector2(1, 1)
		card.z_index = 1

func raycast_check_for_card_slot():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD_SLOT
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		# return result[0].collider.get_parent()
		return result[0].collider.get_parent()
	return null

func raycast_check_for_card():
	var space_state = get_world_2d().direct_space_state
	var parameters = PhysicsPointQueryParameters2D.new()
	parameters.position = get_global_mouse_position()
	parameters.collide_with_areas = true
	parameters.collision_mask = COLLISION_MASK_CARD
	var result = space_state.intersect_point(parameters)
	if result.size() > 0:
		# return result[0].collider.get_parent()
		return get_card_with_highest_z_index(result)
	return null
# Called when the node enters the scene tree for the first time.

func get_card_with_highest_z_index(cards):
	# assume the first card in cards array has the highest z index
	var highest_z_card = cards[0].collider.get_parent()
	var highest_z_index = highest_z_card.z_index

	# loop through the rest of the cards checking for a higher z index
	for i in range(1, cards.size()):
		var current_card = cards[i].collider.get_parent()
		if current_card.z_index > highest_z_index:
			highest_z_card = current_card
			highest_z_index = current_card.z_index
	return highest_z_card

func take(card, player):
	#take a card from another hand
	if player:
		#player has taken card
		player_hand_reference.add_card_to_hand(card, RETURN_TO_HAND_SPEED)
		opponent_hand_reference.remove_card_from_hand(card)
		#if new action add rule
		if $"..".turn == 0:
			print("take added")
			$"..".add_rule($"../CardSlot".card.suit, $"../CardSlot".card.number, 4)
			$"..".toggle_actions(false)
			$"..".turn_finished.emit()
		card.toggle()
	else:
		if $"..".turn == 0:
			$"..".add_rule($"../CardSlot".card.suit, $"../CardSlot".card.number, 5)
			$"..".toggle_actions(false)
			$"..".turn_finished.emit()
		opponent_hand_reference.add_card_to_hand(card, RETURN_TO_HAND_SPEED)
		player_hand_reference.remove_card_from_hand(card)
		#make sure see the correct space
		card.toggle()
		card.toggle_take(false)
		
func looked():
	#player has looked at a card
	$"..".add_rule($"../CardSlot".card.suit, $"../CardSlot".card.number, 6)
	$"..".toggle_actions(false)
	$"..".turn_finished.emit()
	
func swap():
	"""swaps the cards between hands"""
	var swap = player_hand_reference.hand
	player_hand_reference.hand = opponent_hand_reference.hand
	opponent_hand_reference.hand = swap
	opponent_hand_reference.update_hand_positions(0.1)
	for i in opponent_hand_reference.hand:
		i.toggle()
	player_hand_reference.update_hand_positions(0.1)
	for i in player_hand_reference.hand:
		i.toggle()
	
