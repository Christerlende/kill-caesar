extends Control

var game_manager
var round_label: Label
var influence_label: Label
var consul_label: Label
var next_button: Button

func _ready():
	# determine game manager reference
	if get_parent() and get_parent().has_method("start_round"):
		game_manager = get_parent()
	else:
		var scene = get_tree().get_current_scene()
		# if the root scene is a Window wrapper, look for a child named "Game"
		if scene.has_node("Game"):
			game_manager = scene.get_node("Game")
		else:
			game_manager = scene
	print("game_manager is", game_manager, "class", game_manager.get_class())

	# grab UI elements from container
	round_label = $VBoxContainer.get_node_or_null("RoundLabel")
	influence_label = $VBoxContainer.get_node_or_null("InfluenceLabel")
	consul_label = $VBoxContainer.get_node_or_null("ConsulLabel")
	next_button = $VBoxContainer.get_node_or_null("NextButton")
	print("labels:", round_label, influence_label, consul_label, "button", next_button)

	# debug: list children
	print("GameUI children:", get_children())
	for c in get_children():
		print("  child", c.name, "type", c.get_class())

	# connect button if available
	if next_button:
		next_button.connect("pressed", Callable(self, "_on_NextButton_pressed"))
	else:
		print("next_button is null")
func _process(_delta):
	if not game_manager:
		return
	var state = game_manager.state
	if not state:
		return
	if round_label:
		round_label.text = "Round: %d" % state.round_number
	if influence_label:
		influence_label.text = "Influence P:%d / L:%d" % [state.influence_patrician, state.influence_plebian]
	if consul_label:
		var consul = state.players[state.current_consul_index]
		consul_label.text = "Consul: %d (role %d) | Phase: %s" % [consul.player_id, consul.role, state.game_phase]

func _on_NextButton_pressed():
	print("Next button pressed")
	game_manager.progress()
