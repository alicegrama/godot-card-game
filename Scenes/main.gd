"""Within the script of main, the interaction with the main screen is implemented. However most importantly 
it holds the logic for the co-creative tool.

The Co-creative is designed in two phases
SETUP
UNO or POINTS
"""
extends Node2D

@export var tween_intensity: float
@export var tween_duration: float

@onready var playerhand = $PlayerHand
@onready var cardmanager = $CardManager
@onready var opponenthand = $OpponentHand
@onready var cardslot = $CardSlot

@onready var take: Button = $Take
@onready var end: Button = $Button
@onready var uno: Button = $Uno
@onready var points: Button = $Points
@onready var remove: Button = $Remove

var playablecards = []

var state = "setup" #setup, uno, points, done 
var playerstate = "card" #card or action : need to play a card or decide on a action for played card
var round = 1
var skip = false
var turn = 0 #whose turn it is

#uno
var globrules = [2, 3]
#0, 0 = everythin in play
#2: suit on suit -> 1: color on color -> 0:nothing
#3: number on number -> 2: number => n or 1: number <= number -> 0: nothing
var rules = {}
#UNO
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

#VARIABLES FOR THE POINTS GAME
var playerscore = 0
var opponentscore = 0

var pointrules = []
# 0 normal values
# 1 sandwich
# 2 chain
# 3 sequence
# 4 discard
# 5 swap J
# 6 Greed 2
# 7 even odd
# 8 low cards
# 9 face cards
# 10 ranks
# 11 suits
# 12 ying yang
# 13 minefield
# 14 eclips
# 15 gamble
# 16 colors

var ending = 0
var history = []
 


func get_color(suit):
	"""Given a suit returns the color of the suit."""
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
	#To emit a signal when a turn is finished.
	turn_finished.connect(_on_turn_finished)
	
	#initialising the rules.
	for i in range(14):
		for j in ["h", "c", "d", "s"]:
			rules[[j, i]] = null
	$Phase.text = "Phase: Setup phase."
	#start the setup
	setup()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	btn_hovered(take)
	btn_hovered(end)
	btn_hovered(uno)
	btn_hovered(points)
	btn_hovered(remove)
	

func start_tween(object: Object, property: String, final_val: Variant, duration: float):
	var tween = create_tween()
	tween.tween_property(object, property, final_val, duration)
	
	
func btn_hovered(button: Button):
	button.pivot_offset = button.size /2
	if button.is_hovered():
		start_tween(button, "scale", Vector2.ONE * tween_intensity, tween_duration)
	else:
		start_tween(button, "scale", Vector2.ONE, tween_duration)


	
func end_game():
	state = "done"
	$Phase.text = "Finished"
	
func get_rule(name, rule):
	"""get the text for a given rule, given the name of a card"""
	var text = ""
	if rule == 1:
		text += "%s: Give a card from the deck.\n"% [name]
	if rule == 2:
		text += "%s: Skip turn.\n"% [name]
	if rule == 3:
		text += "%s: Change suit.\n"% [name]
	if rule == 4:
		text += "%s: Take a card from opponents hand.\n"% [name]
	if rule == 5:
		text += "%s: Give a card of your hand.\n"% [name]
	if rule == 6:
		text += "%s: Look at a card of the opponent.\n"% [name]
	return text
	
func get_cardname(number):
	"""gives a card name for face cards given its number"""
	if number == 1:
		return 'A'
	if number < 11:
		return str(number)
	if number == 11:
		return 'J'
	if number == 12:
		return 'Q'
	else:
		return 'K'
	
func display_rules():
	"""display the rules of uno"""
	var placetext = "" #text that explains the placement rules
	var ruletext = ""
	#Globrules:
	if globrules == [0,0]:
		placetext += "Everythin goes\n"
	if globrules[0] == 2:
		placetext += "Suit on Suit\n"
	elif globrules[0] == 1:
		placetext += "Color on Color\n"
	if globrules[1] == 3:
		placetext += "Number on Number\n"
	elif globrules[1] == 2:
		placetext += "Numbers greater\n"
	elif globrules[1] == 1:
		placetext += "Numbers smaller\n"
	
	#Card rules
	for i in range(1, 14):
		var rule = []
		var name = ""
		for j in ["h", "c", "d", "s"]:
			rule.append(rules[[j, i]])
		if len(rule.filter(func(element): return element == rule[0])) == 4:
			name = get_cardname(i)
			ruletext += get_rule(name, rule[0])
		else:
			for k in ["h", "c", "d", "s"]:
				name = "%s %s"%[get_cardname(i), k]
				ruletext += get_rule(name, rule[0])

	$Rules.text = ruletext
	$Ending.text = placetext

func check_uno(prevsuit, prevnumber, suit, number):
	"""
	returns true if the given suit number can be played
	in current rules on the previous suit and number
	"""
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
	"""When placement rules are broken, give the new rules where the placement of 
	the number suit, previous number suit can be allowed """
	bot["experiment"] += 0.2 * (1-bot["experiment"])
	if globrules[0] == 2:
		#check if the color is the same.
		if get_color(suit) == get_color(prevsuit):
			globrules[0] = 1
			return
	if globrules[1] == 3:
		#check if greater is allowed
		if number >= prevnumber:
			globrules[1] = 2
			return
		#check if smaller is allowed
		if number <= prevnumber:
			globrules[1] = 1
			return
	else:
		#everything will be allowed
		globrules[0] = 0
		globrules[1] = 0
		

	
func playable(hand):
	"""returns the cards which can be played using the current rules."""
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
	"""When it is the players turn, give the player interaction and set correct states."""
	$Background.color = "2b302b"
	if len(playerhand.hand) == 0 or len(opponenthand.hand) == 0:
		end_game()
	turn = 0
	playerstate = "card"
	if skip:
		skip = false
		turn_finished.emit()
		return
	cardmanager.interaction = true
	if state == "uno":
		await get_tree().create_timer(0.1).timeout
		playablecards = playable(playerhand.hand)
		#show the playable cards
		for i in playablecards:
			i.move_forward()
	else:
		#for points 
		check_rule_decay()
		
	
func random_choice(arr, prob):
	"""take a random choice of an array with probababilities of prob.
	prob needs to have the same length as arr."""
	if len(arr) != len(prob):
		return null
	var p = randf()
	var acu = 0
	for i in range(len(arr)):
		acu += prob[i]
		if p < acu:
			return arr[i]
	return null
	
func uno_decision(card):
	"""on uno the bot decide the rules for his turn"""
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
		elif randf() < bot["rule_pressure"] - (0.1 * bot["aggression"]):
			#remove rule
			for i in ["h", "c", "d", "s"]:
				rules[[i, card.number]] = 0
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
			bot[i] += 0.03* (0.4-bot[i])

func opponent_turn():
	"""oppents turn, if allowed to take action place a card which is allowed."""
	$Background.color = "2b2d2b"
	turn = 1
	if skip:
		skip = false
		turn_finished.emit()
		return
	cardmanager.interaction = false
	await get_tree().create_timer(1.0).timeout
	
	var card = 0
	if state == "uno":
		card = playable(opponenthand.hand).pick_random()
		if card == null:
			#draw a card
			card = cardmanager.draw_deck(opponenthand)
		else:
			card.toggle()
			await cardmanager.place_card(card, opponenthand)
			await uno_decision(card)
			
			if len(opponenthand.hand) == 0:
				#game is over
				end_game()
				return
	else:
		#points
		card = opponenthand.hand.pick_random()
		card.toggle()
		await cardmanager.place_card(card, opponenthand)
		cardmanager.draw_deck(opponenthand)
		history.append([card.suit, card.number])
		#special rules
		special_rules(opponenthand)
		opponentscore += pointscore()
		$OpScore.text = "Score Opp: %d" % [opponentscore]
		
	turn_finished.emit()
	
func playersetup():
	"""A turn for the player in the setup"""
	$Background.color = "2b302b"
	#player can take a action.
	cardmanager.interaction = true
	
	if len(playerhand.hand) >= 10:
		state = "choice"
		cardmanager.interaction = false
		$Uno.visible = true
		$Points.visible = true

func election(pick, seed):
	"""setup for the opponent, with chance to pick a card, stop or set seed."""
	var election = randf()
	if election < pick:
		cardmanager.draw_deck(playerhand)
		cardmanager.draw_deck(opponenthand)
	elif election < seed and cardslot.card == null:
		cardmanager.draw_deck(cardslot)
	else:
		state = "choice"
		cardmanager.interaction = false
		#setup rules
		if cardslot.card != null:
			$Setup.text = "Setup Rules: Draw %d cards, and put a card on the table" % [len(playerhand.hand)]
		else:
			$Setup.text = "Setup Rules: Draw %d cards" % [len(playerhand.hand)]
		$Uno.visible = true
		$Points.visible = true
		
	
func opponentsetup():
	"""opponents turn in the setup, with given changes given the hand size."""
	$Background.color = "2b2d2b"
	#opponent takes a card
	cardmanager.interaction = false
	await get_tree().create_timer(1.0).timeout
	var length = len(opponenthand.hand)
	#Smaller equal than 1 pick a card
	if length <= 1:
		election(1, 0)
	#Smaller then 5 pick a card with 0.8 stop with 0.2
	elif length < 5:
		election(0.8, 0)
	#Smaller than 8 0.45 to pick card, 0.55 to give seed
	elif length < 8:
		election(0.45, 0.55)
	#else 0.25 to pick card, 0.5 to give seed, 0.25 to stop
	else:
		election(0.25, 0.5)
	
	# not higher than 10 cards in the hand
	if len(playerhand.hand) >= 10:
		state = "choice"
		#setup rules
		if cardslot.card != null:
			$Setup.text = "Setup Rules: Draw %d cards, and put a card on the table" % [len(playerhand.hand)]
		else:
			$Setup.text = "Setup Rules: Draw %d cards" % [len(playerhand.hand)]
		cardmanager.interaction = false
		$Uno.visible = true
		$Points.visible = true
	playersetup()
	
func setup():
	"""setup start, where randomly the player or the opponent start"""
	state = "setup"
	if randi() % 2:
		playersetup()
	else:
		opponentsetup()
	
func _on_turn_finished():
	"""an signal for ending the opponents or players turn and give it to the other."""
	#end of a points game
	if state == "points" and checkend():
		state = "done"
		$Phase.text = "Phase: Finished"
		return
	elif state == "uno":
		display_rules()
	if turn == 0:
		if state == "points":
			#make rules and points for players turn
			var prob = 0
			if len(pointrules) < 5:
				prob = 0.8
			else:
				prob = 0.2
			generate_rule(prob)
			#calculate new score
			special_rules(playerhand)
			playerscore += pointscore()
			$PlayScore.text = "Score Player: %d" % [playerscore]
		opponent_turn()

	else:
		round += 1
		$Round.text = "Round: %d" %[round]
		player_turn()
	
func take_action(suit, number, player):
	"""
	take the action for uno given a number suit and player, following the rules.
	Also update the bots emotion values if the player took an action.
	"""
	#with player being true or false
	if player:
		toggle_actions(false)
		var rule = rules[[suit, number]]
		if rule == 1:
			#the opponent draws a card
			bot["aggression"] += 0.2 * 1-bot["aggression"]
			cardmanager.draw_deck(opponenthand)
		elif rule == 2:
			#the opponent is skipped
			bot["aggression"] += 0.2 * (1-bot["aggression"])
			skip = true
		elif rule == 3:
			#you may chooce a new suit
			bot["aggression"] += 0.1 * 1-bot["aggression"]
			toggle_suitbuttons()
			return
		elif rule == 4:
			#you have to take a card of the opponent
			bot["aggression"] += 0.2 * (1-bot["aggression"])
			opponenthand.toggle_take(true)
			return
		elif rule == 5:
			#you can give a card of your own
			bot["aggression"] += 0.2 * (1-bot["aggression"])
			playerhand.toggle_give(true)
			return
		elif rule == 6:
			#you may look at a opponents card
			bot["information"] += 0.2 * (1-bot["information"])
			opponenthand.toggle_look(true)
		turn_finished.emit()
	else:
		var rule = rules[[suit, number]] 
		if rule == 1:
			cardmanager.draw_deck(playerhand)
		elif rule == 2:
			skip = true
		elif rule == 3:
			var s = ['h', 'c', 's', 'd'].pick_random()
			cardslot.card.setup(s, number)
		elif rule == 4:
			cardmanager.take(playerhand.hand.pick_random(), false)
		elif rule == 5:
			cardmanager.take(opponenthand.hand.pick_random(), true)

func toggle_actions(visible):
	"""toggles the action buttons you can take, to being the visible: true or false"""
	playerstate = "action"
	$Button.visible = visible
	
	$Skip.visible = visible
	$Suit.visible = visible
	$Give.visible = visible
	$Take.visible = !visible
	playerhand.toggle_give(visible)
	opponenthand.toggle_take(visible)
	opponenthand.toggle_look(visible)

func _on_button_pressed() -> void:
	"""Button pressed ending of a uno turn or ending of the setup."""
	if state == "setup" and cardmanager.interaction:
		state = "choice"
		cardmanager.interaction = false
		$Button.visible = false
		if cardslot.card != null:
			$Setup.text = "Setup Rules: Draw %d cards, and put a card on the table" % [len(playerhand.hand)]
		else:
			$Setup.text = "Setup Rules: Draw %d cards" % [len(playerhand.hand)]
		$Uno.visible = true
		$Points.visible = true
	if state == "uno" and cardmanager.interaction and playerstate == "action":
		toggle_actions(false)
		turn_finished.emit()

func _on_uno_pressed() -> void:
	"""start a uno turn."""
	$Round.text = "Round 1"
	$Button.text ="No Action"
	$Button.visible = false
	state = "uno"
	$Phase.text = "Phase: Game maker"
	player_turn()
	$Remove.visible = true
	$Uno.visible = false
	$Points.visible = false

func _on_points_pressed() -> void:
	"""start a point turn"""
	$Phase.text = "Phase: Game maker"
	state = "points"
	$Uno.visible = false
	$Points.visible = false
	$OpScore.visible = true
	$PlayScore.visible = true
	$Button.visible = false
	$Take.visible = false
	initial_rules()
	player_turn()
	
func add_rule(suit, number, rule):
	"""For uno add the given rule to the card suit number."""
	bot["rule_changer"] += 0.2 * (1-bot["rule_changer"])
	if rules[[suit, number]] not in [null, 0]:
		rules[[suit, number]] = rule
		return
	for i in ["h", "c", "d", "s"]:
		if rules[[i, number]] == null or rules[[i, number]] == 0:
			rules[[i, number]] = rule
			
func toggle_suitbuttons():
	"""The buttons to change the suit of the played card"""
	$Heart.visible = !$Heart.visible
	$Club.visible = !$Club.visible
	$Spade.visible = !$Spade.visible
	$Diamond.visible = !$Diamond.visible

#BUTTONS
func _on_give_pressed() -> void:
	"""The give button is pressed, the opponent is given a card."""
	if state == "uno" and cardmanager.interaction and playerstate == "action":
		cardmanager.draw_deck(opponenthand)
		add_rule(cardslot.card.suit, cardslot.card.number, 1)
		toggle_actions(false)
		turn_finished.emit()

func _on_take_pressed() -> void:
	"""take a card, can be done in uno as well as in the setup."""
	if state == "uno" and cardmanager.interaction and playerstate == "card":
		cardmanager.draw_deck(playerhand)
		turn_finished.emit()
	elif state == "setup" and cardmanager.interaction:
		cardmanager.draw_deck(playerhand)
		cardmanager.draw_deck(opponenthand)
		opponentsetup()


func _on_skip_pressed() -> void:
	"""The skip button adds the rule skip to the card"""
	if state == "uno" and cardmanager.interaction and playerstate == "action":
		add_rule(cardslot.card.suit, cardslot.card.number, 2)
		take_action(cardslot.card.suit, cardslot.card.number, 1)


func _on_suit_pressed() -> void:
	"""Adds the rule to change the suit on a card."""
	if state == "uno" and cardmanager.interaction and playerstate == "action":
		add_rule(cardslot.card.suit, cardslot.card.number, 3)
		take_action(cardslot.card.suit, cardslot.card.number, 1)
	
#BUTTONS to change the suit of the card at the top of the dicard.
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
	
#Underneath is every extra function for the points game

func initial_rules():
	"""decide the initial rules of the points game"""
	#decide ending
	ending = randi() % 4
	if ending == 0:
		$Ending.text = "Ending: Race to 200 pts"
	if ending == 1:
		$Ending.text = "Ending: Hourglass (20 Turns)"
	if ending == 2:
		$Ending.text = "Ending: The Beast (3 Sixes on table)"
	if ending == 3:
		$Ending.text = "Ending: Panic Button (Play a Q after turn 10)"
		
	pointrules = [[[0], [11, ["Hearts", "Clubs", "Diamonds", "Spades"].pick_random()], [16], [8], [9], [8, 6, 10], [3], [1], [2]].pick_random()]
	pointscore()

func check_rule_decay():
	"""Removes rules to reduce clutter."""
	var nrules = len(pointrules) 
	var decay_prob = max(0, (nrules-3)*0.1)
	if pointrules and randf() < decay_prob:
		#remove a rule
		pointrules.pop_front()
		
func generate_rule(prob):
	"""add a rule given a probability"""
	var nrules = len(pointrules)
	# Logic 60% Justification / 40% Complex
	if randf() < prob:
		if randf() < 0.75:
			create_justification_rule()
			if len(pointrules) == nrules:
				create_complex_rule()
		else:
			create_complex_rule()
			if len(pointrules) == nrules:
				create_justification_rule()

func create_justification_rule():
	"""Creates rules based on the play. 
	HIGH PRIORITY: Returns immediately. 
	MEDIUM/LOW PRIORITY: Added to a pool and chosen by WEIGHT."""
	
	var weighted_candidates = []
	var probs = []
	
	#sandwhich detection
	if len(history) >= 3:
		var card_minus2 = history[-3]
		if history[-1][1] == card_minus2[1]:
			if not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 1):
				pointrules.append([1])
				return
	#sequence detection
	if len(history) >= 2:
		if abs(history[-1][1] - history[-2][1]) == 1:
			var is_chain = false
			if len(history) >= 3:
				if abs(history[-2][1] - history[-3][1]) == 1:
					is_chain = true
			if is_chain and not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 2):
				pointrules.append([2])
				return
			elif not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 3):
				pointrules.append([3])
				return
	#destroy rule
	if history[-1][1] == 7 and not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 4):
		probs.append(40)
		weighted_candidates.append([4])
	# swap on J
	if history[-1][1] == 11 and not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 5):
		weighted_candidates.append([5])
		probs.append(30)
	# 2 adds a card to the hand
	if history[-1][1] == 2 and not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 6):
		weighted_candidates.append([6])
		probs.append(30)
	# even odd
	if not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 7):
		weighted_candidates.append([7, (history[-1][1]%2) == 1])
		probs.append(15)
	# low cards
	if history[-1][1] <= 5 and not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 8):
		weighted_candidates.append([8])
		probs.append(15)
	# face cards
	if history[-1][1] >= 11 and not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 9):
		weighted_candidates.append([9])
		probs.append(10)
	# ranks
	if not pointrules.any(func(arr): return arr.size() > 0 and arr[0] == 10):
		weighted_candidates.append([10, history[-1][1]])
		probs.append(20)
	# suits
	if [11, history[-1][0]] not in pointrules and len(pointrules.filter(func(arr): return arr.size() > 0 and arr[0] == 11)) <2:
		weighted_candidates.append([11, history[-1][0]])
		probs.append(10)
	# choose candidate
	if weighted_candidates:
		var total = 0
		for i in probs:
			total += i
		for i in range(len(probs)):
			probs[i] = float(probs[i])/float(total)
		pointrules.append(random_choice(weighted_candidates, probs))
		
func create_complex_rule():
	var weighted_candidates = []
	var probs = []
	if [12] not in pointrules:
		var gsuit = ["h", "c", "d", "s"].pick_random()
		var gnumber = randi() % 13 +1
		var dsuit = ["h", "c", "d", "s"].pick_random()
		var dnumber = randi() % 13 +1
		weighted_candidates.append([12, gsuit, gnumber, dsuit, dnumber])
		probs.append(20)
	if [13] not in pointrules:
		var mine_val = randi() % 13 +2
		var offset = randi() % 5
		var start = mine_val - offset
		var end = mine_val + 4 + offset
		if start < 2:
			end += 6
			start = 2
		if end > 13:
			start = 9
			end = 13
			
		weighted_candidates.append([13, mine_val, start, end])
		probs.append(30)
	if [14] not in pointrules:
		weighted_candidates.append([14])
		probs.append(30)
	if [15] not in pointrules:
		weighted_candidates.append([15])
		probs.append(30)
		
	if weighted_candidates:
		var total = 0
		for i in probs:
			total += i
		for i in range(len(probs)):
			probs[i] = float(probs[i])/float(total)
		pointrules.append(random_choice(weighted_candidates, probs))
		
func pointscore():
	"""returns value of top card
	and now also updates the rules on the label.
	"""
	var score = 0
	var textrules = ""
	for i in pointrules:
		if i[0] == 0:
			textrules += "\n Standard Value: Points = Card value (2-14)."
			score += value_rule()
		if i[0] == 1:
			textrules += "\n Sandwich (e.g., 5-K-5): Steal middle value + 30 pts."
			score += sandwich_rule()
		if i[0] == 2:
			textrules += "\n Chain Reaction: Extend existing sequence -> +50 pts."
			score += chain_rule()
		if i[0] == 3:
			textrules += "\n Sequence: Consecutive -> +20 pts."
			score += sequence_rule()
		if i[0] == 4:
			textrules += "\n Destroyer: 7 removes a card."
		if i[0] == 5:
			textrules += "\n The Trickster: J swaps hands"
		if i[0] == 6:
			textrules += "\n Greed: Playing a 2 gives you an extra card immediately (hand size increases)."
		if i[0] == 7:
			if i[1]:
				textrules += "\n Law of evens: even cards give +8 pts."
			score += even_odd_rule(i[1])
		if i[0] == 8:
			textrules += "\n Micro-Power: Low cards (2-5) give +15 pts."
			score += micro_rule()
		if i[0] == 9:
			textrules += "\n Royal Court: Face cards give +10 pts."
			score += face_rule()
		if i[0] == 10:
			textrules += "\n Obsession %d: Playing '%d' gives +25 pts." %[i[1], i[1]]
			score += rank_rule(i[1])
		if i[0] == 11:
			textrules += "\n Law of %s: %s cards: +10 pts." %[i[1], i[1]]
			score += suit_rule(i[1])
		if i[0] == 12:
			textrules += "\n Universal Balance: There is a HIDDEN card that is God (+100 pts)\n and another Devil (-100 pts)."
			score += yingyang_rule(i[1], i[2], i[3], i[4])
		if i[0] == 13:
			textrules += "\n Minefield: %d - %d gives +20 pts... But there is a MINE!" % [i[2],i[3]]
			score += minefield_rule(i[1], i[2], i[3])
		if i[0] == 14:
			textrules += "\n SOLAR ECLIPSE! The hierarchy is inverted: 2 is the strongest (Ace),\n Ace is the weakest (2)."
			score += eclips_rule()
		if i[0] == 15:
			textrules += "\n Gambling:Face cards +15, Low cards -10."
			score += gamble_rule() 
		if i[0] == 16:
			textrules += "\n Chromatic Flow:Same color +5. Different -5."
			score += colors_rule() 
	$Rules.text = textrules
	return score
	
func value_rule():
	"""return the value of the card"""
	if len(history) == 0:
		return 0
	if len(history) > 0 and history [-1][1] == 1:
		return 14
	return history[-1][1]

func sandwich_rule():
	"""30 points if there is a card between two identical numbers"""
	if len(history) >= 3 and history[-1][1] == history[-3][1]:
		#current rank is the same as two back
		return 30 + history[-1][1]
	return 0

func chain_rule():
	"""When 3 card after eachother and differece 1 as numbers give 50 points."""
	if len(history) >= 3:
		var card = history[-1]
		var prev = history[-2]
		var pre_prev = history[-3]
		if abs(prev[1] - pre_prev[1]) == 1 and abs(card[1] - prev[1]) == 1:
			return 50
	return 0
		
func sequence_rule():
	"""When a card is one rank from the previous, give 20 points"""
	if len(history) >= 3:
		var card = history[-1]
		var prev = history[-2]
		if abs(card[1] - prev[1]) == 1:
			return 20
	return 0
	
func draw_rule(hand):
	"""Draw a card from the given hand"""
	if len(history) > 0 and history[-1] == 2:
		cardmanager.draw_card(hand)
		
func even_odd_rule(even):
	"""Given a boolean even.
	given 8 points appropiate to if the card is even or not."""
	if len(history) > 0 and history[-1][1] % 2 == int(even):
		return 8
	return 0

func micro_rule():
	"""Give low cards smaller equal to 5, 15 points."""
	if len(history) > 0 and history[-1][1] <= 5 and history[-1][1] > 1 :
		return 15
	return 0
	
func face_rule():
	"""Give cards with a face 10 points."""
	if len(history) > 0 and history[-1][1] >= 11:
		return 10
	return 0
	
func rank_rule(rank):
	if len(history) > 0 and history[-1][1] == rank:
		return 25
	return 0

func suit_rule(suit):
	if len(history) > 0 and history[-1][0] == suit:
		return 25
	return 0
	
func yingyang_rule(gsuit, gnumber, dsuit, dnumber):
	if len(history) > 0 and history[-1][0] == gsuit and history[-1][1] == gnumber:
		return 100
	if len(history) > 0 and history[-1][0] == dsuit and history[-1][1] == dnumber:
		return -100
	return 0

func minefield_rule(number, lower, upper):
	if len(history) > 0 and history[-1][1] == number:
		return -50
	if len(history) > 0 and lower <= history[-1][1] and history[-1][1] <= upper:
		return 20
	return 0
	
func eclips_rule():
	if len(history) > 0 and history[-1][1] == 1:
		return 2
	return 16 - (2 * history[-1][1])
	
func gamble_rule():
	if len(history) > 0 and history[-1][1] > 10 :
		return 15
	if len(history) > 0 and history[-1][1] < 6:
		return -10
	return 0
	
func colors_rule():
	if len(history) >= 2 and get_color(history[-1][0]) == get_color(history[-2][0]):
		return 5
	return -5
	
func checkend():
	"""checks the end for points game"""
	if ending == 0 and (playerscore > 200 or opponentscore > 200):
		return true
	if ending == 1 and  round >= 20:
		return true
	if ending == 2 and len(history.filter(func(arr): return arr.size() > 0 and arr[1] == 6)) == 3:
		return true
	if ending == 3 and round >= 10 and history[-1][1] == 12:
		return true
	return false
	
func special_rules(hand):
	for i in pointrules:
		if history[-1][1] == 7 and i[0] == 4:
			if len(hand.hand) > 1:
				var card = hand.hand.pick_random()
				if hand == opponenthand:
					card.toggle()
				cardmanager.place_card(card, hand)
		if history[-1][1] == 2 and i[0] == 6:
			cardmanager.draw_deck(hand)
		if history[-1][1] == 11 and i[0] == 5:
			cardmanager.swap()


func _on_remove_pressed() -> void:
	#remove the rules of all cards with number
	if cardslot.card:
		for i in ["h", "c", "d", "s"]:
			rules[[i, cardslot.card.number]] = 0
		display_rules()
		bot["rule_changer"] += 0.2 * (1-bot["rule_changer"])


func start_tutorial() -> void:
	pass # Replace with function body.
