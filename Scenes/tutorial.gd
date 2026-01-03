extends Node

@onready var dim_overlay: ColorRect = $RootControl/DimOverlay
@onready var intro_layer: Control = $RootControl/UILayer/IntroLayer

@onready var deck: CanvasItem = $"../Deck"
@onready var rules_panel: CanvasItem = $"../Rules"
@onready var end_button: CanvasItem = $"../Button"

@onready var tooltip: Control = $RootControl/UILayer/Tooltip
@onready var tooltip_label: Label = $RootControl/UILayer/Tooltip/TooltipLabel



var spotlight_material: ShaderMaterial
var step: int = 0

var steps: Array[Dictionary] = []


func _ready() -> void:
	spotlight_material = dim_overlay.material as ShaderMaterial

	steps = [
		{
			"target": deck,
			"text": "This is the deck. Drawing cards is one of the core actions."
		},
		{
			"target": rules_panel,
			"text": "Rules appear here as they are created during play."
		},
		{
			"target": end_button,
			"text": "End the setup phase once you're satisfied with the starting rules."
		}
	]

	show_intro()



func show_intro() -> void:
	dim_overlay.visible = true
	intro_layer.visible = true
	disable_spotlight()


func start_tutorial() -> void:
	intro_layer.visible = false
	step = 0
	next_step()


func next_step() -> void:
	if step >= steps.size():
		end_tutorial()
		return

	var data: Dictionary = steps[step]
	var target: CanvasItem = data["target"]
	var text: String = data["text"]

	move_spotlight_to(target)
	show_tooltip(text, target)


func show_tooltip(text: String, target: CanvasItem) -> void:
	tooltip.visible = true
	tooltip_label.text = text

	# Position tooltip slightly below spotlight
	var viewport_size := get_viewport().get_visible_rect().size
	var global_pos: Vector2

	if target is Control:
		global_pos = (target as Control).get_global_rect().get_center()
	else:
		global_pos = target.global_position

	tooltip.global_position = global_pos + Vector2(-150, 120)



func move_spotlight_to(target: CanvasItem) -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var global_pos: Vector2
	
	if target is Control:
		global_pos = (target as Control).get_global_rect().get_center()
	else:
		global_pos = target.global_position


	var uv := Vector2(
		global_pos.x / viewport_size.x,
		global_pos.y / viewport_size.y
	)

	dim_overlay.visible = true
	spotlight_material.set_shader_parameter("spotlight_pos", uv)
	spotlight_material.set_shader_parameter("spotlight_radius", 0.18)


func disable_spotlight() -> void:
	spotlight_material.set_shader_parameter("spotlight_radius", 0.0)


func end_tutorial() -> void:
	dim_overlay.visible = false
	queue_free()


func _input(event: InputEvent) -> void:
	# Don't advance while intro screen is up
	if intro_layer.visible:
		return

	# Left click advances
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		step += 1
		next_step()
		get_viewport().set_input_as_handled() # optional, prevents clicks also clicking game/UI

	# Optional: keyboard advances too
	if event.is_action_pressed("ui_accept"):
		step += 1
		next_step()
		get_viewport().set_input_as_handled()
