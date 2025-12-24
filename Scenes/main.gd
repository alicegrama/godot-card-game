extends Node2D

@onready var playerhand = $PlayerHand
@onready var cardmanager = $CardManager
@onready var opponenthand = $OpponentHand
@onready var cardslot = $CardSlot

var playablecards = []

var state = "setup" #setup, uno, points, done 
var playerstate = "card" #card or action : need to play a card or decide on a action for played card
var round = 0
var skip = false
var turn = 0 #whose turn it is

#uno
var globrules = [2, 3]
#0, 0 = everythin in play
#2: suit on suit -> 1: color on color -> 0:nothing
#3: number on number -> 2: number => n or 1: number <= number -> 0: nothing
#1: numbers have same rules -> 0: number-suit a rule.
var rules = {} 
#0 = nothing, 1 = take a card, 2 = your turn, 3 = change suit, 
#4 = give/take card of hand, 5 = look at card

#we model the player to get a appropiate bot, reflecting the creation of the player
var bot = {
	"rule_changer" : 0.4, #for changing rules
	"aggression" : 0.5, #for makking aggresive rules
	"information" : 0.3, #for taking information rules
	"experiment" : 0.1, #for breaking global rules
	"rule_pressure": 0.0 #to avoid clutter
}

signal turn_finished
 
func get_color(suit):
	if suit == 's':
		return 0
	if suit == 'h':
		return 1
	if suit == 'd':
		return 1
	if suit == 'c':
		return 0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	turn_finished.connect(_on_turn_finished)
	for i in range(14):
		for j in ["h", "c", "d", "s"]:
			rules[[j, i]] = null
	start_game()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func check_uno(prevsuit, prevnumber, suit, number):
	#returns true if it can be played in current rules
	if globrules[0] == 0 and globrules[1] == 0:
		return true
	if globrules[0] == 2:
		if prevsuit == suit:
			return true
	elif globrules[0] == 1:
		if get_color(prevsuit) == get_color(suit):
			return true
	if globrules[1] == 3:
		if prevnumber == number:
			return true
	elif globrules[1] == 2:
		if number >= prevnumber:
			return true
	elif globrules[1] == 1:
		if number <= prevnumber:
			return true
			
func change_rules(number, suit, prevnumber, prevsuit):
	if globrules[0] == 2:
		if get_color(suit) == get_color(prevsuit):
			print("colors now")
			globrules[0] = 1
			return
	if globrules[1] == 3:
		if number >= prevnumber:
			print("greater now")
			globrules[1] = 2
			return
		if number <= prevnumber:
			print("lesser now")
			globrules[1] = 1
			return
	else:
		print("all in")
		globrules[0] = 0
		globrules[1] = 0
		

	
func playable(hand):
	#depending on the rules return playble cards of hand
	var prevcard = cardslot.card
	if prevcard == null:
		return hand
	var arr = []
	for i in hand:
		if check_uno(prevcard.suit, prevcard.number, i.suit, i.number):
			arr.append(i)
	return arr
	
func player_turn():
	turn = 0
	playerstate = "card"
	if skip:
		skip = false
		turn_finished.emit()
		return
	playablecards = playable(playerhand.hand)
	#show the playable cards
	for i in playablecards:
		i.move_forward()
	cardmanager.interaction = true
	
func random_choice(arr, prob):
	#take a random choice of array with probababilities of prob
	# prob needs to have the same length
	if len(arr) != len(prob):
		return null
	var p = randf()
	var acu = 0
	for i in range(len(arr)):
		acu += prob[i]
		if p < acu:
			return arr[i]
	return null

func opponent_turn():
	turn = 1
	if skip:
		skip = false
		turn_finished.emit()
		return
	cardmanager.interaction = false
	await get_tree().create_timer(1.0).timeout
	var card = playable(opponenthand.hand).pick_random()
	if card == null:
		#draw a card
		card = cardmanager.draw_deck(opponenthand)
	else:
		card.toggle()
		await cardmanager.place_card(card, opponenthand)
		
		if len(opponenthand.hand) == 0:
			#game is over
			print("gameover")
			return
		
		#action with card
		var rule = 0
		if rules[[card.suit, card.number]] == 0:
			var probs = 0.02 + (0.01 * bot["rule_changer"]) + (0.01 * bot["aggression"]) - (0.03 * bot["rule_pressure"])
			var inf = 0.02 + (0.01 * bot["rule_changer"]) + (0.01 * bot["information"]) - (0.03 * bot["rule_pressure"])
			if probs < 0:
				probs = 0
			rule = random_choice(range(6), [1-(probs*4)-inf, probs, probs, probs, probs, inf])
			add_rule(card.suit, card.number, rule)
		elif rules[[card.suit, card.number]] == null:
			var probs = 0.03 + (0.02 * bot["rule_changer"]) + (0.02 * bot["aggression"]) - (0.03 * bot["rule_pressure"])
			var inf = 0.03 + (0.02 * bot["rule_changer"]) + (0.02 * bot["information"]) - (0.03 * bot["rule_pressure"])
			if probs < 0:
				probs = 0
			rule = random_choice(range(6), [1-(probs*4)-inf, probs, probs, probs, probs, inf])
			add_rule(card.suit, card.number, rule)
		else:
			var probs = 0.02 + (0.02 * bot["rule_changer"]) + (0.02 * bot["aggression"])
			if randf() < probs:
				var inf = 0.02 + (0.02 * bot["rule_changer"]) + (0.02 * bot["information"])
				if probs < 0:
					probs = 0
				rule = random_choice(range(6), [1-(probs*4)-inf, probs, probs, probs, probs, inf])
				add_rule(card.suit, card.number, rule)
		take_action(card.suit, card.number, false)
	
	#decrease bots emotions
	for i in bot:
		if i == 'rule_pressure':
			var nrules = 0
			for x in rules.values():
				if x != 0 and x != null:
					nrules += 1
			bot[i] = nrules/len(rules)
		else:
			bot[i] += 0.03* -bot[i]
	turn_finished.emit()
	
func playersetup():
	#player can take a action.
	cardmanager.interaction = true
	
	if len(playerhand.hand) >= 10:
		state = "choice"
		cardmanager.interaction = false
		$Uno.visible = true
		$Points.visible = true

func election(pick, seed):
	#setup choice for opponent
	#with chance to pickcards, and set seed
	var election = randf()
	if election < pick:
		cardmanager.draw_deck(playerhand)
		cardmanager.draw_deck(opponenthand)
	elif election < seed and cardslot.card == null:
		cardmanager.draw_deck(cardslot)
	else:
		state = "choice"
		cardmanager.interaction = false
		$Uno.visible = true
		$Points.visible = true
		
	
func opponentsetup():
	#opponent takes a card
	cardmanager.interaction = false
	await get_tree().create_timer(1.0).timeout
	var length = len(opponenthand.hand)
	#Smaller than 3 0.7 to pick card
	if length < 1:
		election(1, 0)
	elif length < 3:
		election(0.7, 0)
	#Smaller than 7 0.4 to pick card, 0.5 to give seed
	elif length < 7:
		election(0.4, 0.5)
	#Else 0.25 to pick card, 0.5 to give seed
	else:
		election(0.25, 0.5)
	
	if len(playerhand.hand) >= 10:
		state = "choice"
		cardmanager.interaction = false
		$Uno.visible = true
		$Points.visible = true
	playersetup()
	
func setup():
	#randomly start with 
	state = "setup"
	if randi() % 2:
		playersetup()
	else:
		opponentsetup()
	
func _on_turn_finished():
	if turn == 0:
		opponent_turn()
	else:
		round += 1
		player_turn()

func start_game():
	setup()
	pass
	
func take_action(suit, number, player):
	#take the action on a given card following the rules
	#with player being true or false
	if player:
		toggle_actions(false)
		var rule = rules[[suit, number]]
		if rule == 1:
			#the opponent draws a card
			cardmanager.draw_deck(opponenthand)
		elif rule == 2:
			#the opponent is skipped
			print("skip")
			skip = true
		elif rule == 3:
			#you may chooce a new suit
			toggle_suitbuttons()
			return
		elif rule == 4:
			#you have to take a card of the opponent
			opponenthand.toggle_take(true)
			return
		elif rule == 5:
			#you can give a card of your own
			playerhand.toggle_give(true)
			return
		elif rule == 6:
			#you may look at a opponents card
			opponenthand.toggle_look(true)
		else:
			pass
		turn_finished.emit()
	else:
		var rule = rules[[suit, number]] 
		if rule == 1:
			cardmanager.draw_deck(playerhand)
		elif rule == 2:
			skip = true
			print("hi ")
		elif rule == 3:
			var s = ['h', 'c', 's', 'd'].pick_random()
			cardslot.card.setup(s, number)
		elif rule == 4:
			cardmanager.take(playerhand.hand.pick_random(), false)
		elif rule == 5:
			cardmanager.take(opponenthand.hand.pick_random(), true)

func toggle_actions(visible):
	#toggles the action buttons you can take
	playerstate = "action"
	$Skip.visible = visible
	$Suit.visible = visible
	$Give.visible = visible
	$Take.visible = !visible
	playerhand.toggle_give(visible)
	opponenthand.toggle_take(visible)
	opponenthand.toggle_look(visible)

func _on_button_pressed() -> void:
	if state == "setup" and cardmanager.interaction:
		state = "choice"
		cardmanager.interaction = false
		$Uno.visible = true
		$Points.visible = true
	if state == "uno" and cardmanager.interaction and playerstate == "action":
		toggle_actions(false)
		turn_finished.emit()

func _on_uno_pressed() -> void:
	state = "uno"
	player_turn()
	$Uno.visible = false
	$Points.visible = false

func _on_points_pressed() -> void:
	state = "points"
	$Uno.visible = false
	$Points.visible = false
	#TODO here need to start points game
	
func add_rule(suit, number, rule):
	if rules[[suit, number]] not in [null, 0]:
		rules[[suit, number]] = rule
		return
	print("added rule")
	for i in ["h", "c", "d", "s"]:
		if rules[[i, number]] == null or rules[[i, number]] == 0:
			rules[[i, number]] = rule

func _on_give_pressed() -> void:
	if state == "uno" and cardmanager.interaction and playerstate == "action":
		cardmanager.draw_deck(opponenthand)
		add_rule(cardslot.card.suit, cardslot.card.number, 1)
		toggle_actions(false)
		turn_finished.emit()
	elif state == "setup" and cardmanager.interaction:
		cardmanager.draw_deck(playerhand)
		cardmanager.draw_deck(opponenthand)
		opponentsetup()

func _on_take_pressed() -> void:
	if state == "uno" and cardmanager.interaction and playerstate == "card":
		cardmanager.draw_deck(playerhand)
		turn_finished.emit()
	elif state == "setup" and cardmanager.interaction:
		cardmanager.draw_deck(playerhand)
		cardmanager.draw_deck(opponenthand)
		opponentsetup()


func _on_skip_pressed() -> void:
	if state == "uno" and cardmanager.interaction and playerstate == "action":
		add_rule(cardslot.card.suit, cardslot.card.number, 2)
		take_action(cardslot.card.suit, cardslot.card.number, 1)


func _on_suit_pressed() -> void:
	if state == "uno" and cardmanager.interaction and playerstate == "action":
		add_rule(cardslot.card.suit, cardslot.card.number, 3)
		take_action(cardslot.card.suit, cardslot.card.number, 1)

func toggle_suitbuttons():
	$Heart.visible = !$Heart.visible
	$Club.visible = !$Club.visible
	$Spade.visible = !$Spade.visible
	$Diamond.visible = !$Diamond.visible
	

func _on_heart_pressed() -> void:
	toggle_suitbuttons()
	cardslot.card.setup("h", cardslot.card.number)
	turn_finished.emit()


func _on_club_pressed() -> void:
	toggle_suitbuttons()
	cardslot.card.setup("c", cardslot.card.number)
	turn_finished.emit()


func _on_spade_pressed() -> void:
	toggle_suitbuttons()
	cardslot.card.setup("s", cardslot.card.number)
	turn_finished.emit()


func _on_diamond_pressed() -> void:
	toggle_suitbuttons()
	cardslot.card.setup("d", cardslot.card.number)
	turn_finished.emit()
	
func end_game():
	state = "done"
