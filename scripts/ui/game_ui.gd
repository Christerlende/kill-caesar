extends Control

var game_manager
var round_label: Label
var influence_label: Label
var consul_label: Label
var nominee_buttons_container: HBoxContainer
var election_votes_container: VBoxContainer
var policy_discard_buttons_container: HBoxContainer
var spending_controls_container: VBoxContainer
var player_purses_label: Label
var phase_info_label: Label
var next_button: Button
var _nominee_ui_key: String = ""
var _vote_ui_key: String = ""
var _policy_ui_key: String = ""
var _spending_ui_key: String = ""

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
	nominee_buttons_container = $VBoxContainer.get_node_or_null("NomineeButtonsContainer")
	election_votes_container = $VBoxContainer.get_node_or_null("ElectionVotesContainer")
	policy_discard_buttons_container = $VBoxContainer.get_node_or_null("PolicyDiscardButtonsContainer")
	spending_controls_container = $VBoxContainer.get_node_or_null("SpendingControlsContainer")
	player_purses_label = $VBoxContainer.get_node_or_null("PlayerPursesLabel")
	phase_info_label = $VBoxContainer.get_node_or_null("PhaseInfoLabel")
	next_button = $VBoxContainer.get_node_or_null("NextButton")
	print("labels:", round_label, influence_label, consul_label, nominee_buttons_container, election_votes_container, policy_discard_buttons_container, spending_controls_container, player_purses_label, phase_info_label, "button", next_button)

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
		influence_label.text = "Patrician Influence: %d | Plebian Influence: %d" % [state.influence_patrician, state.influence_plebian]
	if consul_label:
		var consul = state.players[state.current_consul_index]
		var co_consul_text = "Not chosen yet"
		if state.current_co_consul_index >= 0:
			var co_consul = state.players[state.current_co_consul_index]
			co_consul_text = "Player %d (%s)" % [co_consul.player_id, game_manager.role_name(co_consul.role)]
		consul_label.text = "Consul: Player %d (%s) | Co-Consul: %s" % [consul.player_id, game_manager.role_name(consul.role), co_consul_text]
	if player_purses_label:
		player_purses_label.text = _build_player_purses_text(state)
	if phase_info_label:
		phase_info_label.text = _build_phase_text(state)
	_update_nominee_buttons(state)
	_update_election_vote_buttons(state)
	_update_policy_discard_buttons(state)
	_update_spending_controls(state)
	if next_button:
		next_button.disabled = (state.game_phase == "election" and (state.election_nominee_index < 0 or not game_manager.are_election_votes_complete())) or (state.game_phase == "policy" and state.policy_enacted == null) or (state.game_phase == "spending" and state.spending_stage != "resolved")

func _update_nominee_buttons(state) -> void:
	if not nominee_buttons_container:
		return
	var ui_key = "%s|%d|%d" % [state.game_phase, state.current_consul_index, state.election_nominee_index]
	if ui_key == _nominee_ui_key:
		return
	_nominee_ui_key = ui_key
	for child in nominee_buttons_container.get_children():
		child.queue_free()
	if state.game_phase != "election" or state.election_nominee_index >= 0:
		return
	var candidates = game_manager.get_nominee_candidates()
	for candidate_index in candidates:
		var b = Button.new()
		b.text = "Choose Co-Consul: Player %d" % candidate_index
		b.pressed.connect(Callable(self, "_on_nominee_button_pressed").bind(candidate_index))
		nominee_buttons_container.add_child(b)

func _update_election_vote_buttons(state) -> void:
	if not election_votes_container:
		return
	var ui_key = "%s|%d|%s" % [state.game_phase, state.election_nominee_index, _vote_inputs_signature(state)]
	if ui_key == _vote_ui_key:
		return
	_vote_ui_key = ui_key
	for child in election_votes_container.get_children():
		child.queue_free()
	if state.game_phase != "election" or state.election_nominee_index < 0:
		return
	for player_id in range(state.players.size()):
		var row = HBoxContainer.new()
		var vote_state = state.election_vote_inputs[player_id]
		var vote_text = "Pending"
		if vote_state == 1:
			vote_text = "YES"
		elif vote_state == 0:
			vote_text = "NO"
		var label = Label.new()
		label.text = "Player %d vote: %s" % [player_id, vote_text]
		var yes_button = Button.new()
		yes_button.text = "Yes"
		yes_button.pressed.connect(Callable(self, "_on_vote_yes_pressed").bind(player_id))
		var no_button = Button.new()
		no_button.text = "No"
		no_button.pressed.connect(Callable(self, "_on_vote_no_pressed").bind(player_id))
		row.add_child(label)
		row.add_child(yes_button)
		row.add_child(no_button)
		election_votes_container.add_child(row)

func _vote_inputs_signature(state) -> String:
	var parts = []
	for vote in state.election_vote_inputs:
		parts.append(str(vote))
	return ",".join(parts)

func _update_policy_discard_buttons(state) -> void:
	if not policy_discard_buttons_container:
		return
	var candidates = game_manager.get_policy_discard_candidates()
	var ui_key = "%s|%s|%s|%d" % [state.game_phase, game_manager.get_policy_discard_stage(), _int_list_signature(candidates), state.policy_discarded_ids.size()]
	if ui_key == _policy_ui_key:
		return
	_policy_ui_key = ui_key
	for child in policy_discard_buttons_container.get_children():
		child.queue_free()
	if state.game_phase != "policy" or state.policy_enacted != null:
		return
	var stage = game_manager.get_policy_discard_stage()
	if stage == "":
		return
	var actor = "Consul" if stage == "consul" else "Co-Consul"
	for policy_id in candidates:
		var b = Button.new()
		b.text = "%s discards Policy #%d" % [actor, policy_id]
		b.pressed.connect(Callable(self, "_on_policy_discard_pressed").bind(policy_id))
		policy_discard_buttons_container.add_child(b)

func _int_list_signature(values: Array) -> String:
	var parts = []
	for v in values:
		parts.append(str(v))
	return ",".join(parts)

func _update_spending_controls(state) -> void:
	if not spending_controls_container:
		return
	var ui_key = "%s|%s|%d" % [state.game_phase, state.spending_stage, state.spending_input_player_index]
	if ui_key == _spending_ui_key:
		return
	_spending_ui_key = ui_key
	for child in spending_controls_container.get_children():
		child.queue_free()
	if state.game_phase != "spending":
		return
	if state.spending_stage == "input":
		var player_id = game_manager.get_current_spending_player_id()
		var money = game_manager.get_current_spending_player_money()
		var title = Label.new()
		title.text = "Private spending input: Player %d" % player_id
		spending_controls_container.add_child(title)
		var hint = Label.new()
		hint.text = "Choose how much goes to Option A. Remaining goes to Option B."
		spending_controls_container.add_child(hint)
		var buttons_row = HBoxContainer.new()
		for amount_a in range(money + 1):
			var b = Button.new()
			var amount_b = money - amount_a
			b.text = "A:%d / B:%d" % [amount_a, amount_b]
			b.pressed.connect(Callable(self, "_on_spending_split_pressed").bind(amount_a))
			buttons_row.add_child(b)
		spending_controls_container.add_child(buttons_row)
	elif state.spending_stage == "handoff":
		var handoff = Label.new()
		handoff.text = "Private entry saved. Pass to next player."
		spending_controls_container.add_child(handoff)
		var ready = Button.new()
		ready.text = "Ready for next player"
		ready.pressed.connect(Callable(self, "_on_spending_ready_next_pressed"))
		spending_controls_container.add_child(ready)
	elif state.spending_stage == "resolved":
		var done = Label.new()
		done.text = "All private spending captured. Totals are now public."
		spending_controls_container.add_child(done)

func _build_player_purses_text(state) -> String:
	var parts = []
	for player in state.players:
		parts.append("Player %d (%s): %d" % [player.player_id, game_manager.role_name(player.role), player.money])
	return " | ".join(parts)

func _build_phase_text(state) -> String:
	var lines = ["Phase: %s" % state.game_phase]

	# Election results (show after election has run)
	if state.election_nominee_index >= 0:
		var nominee = state.players[state.election_nominee_index]
		lines.append("Nominee: Player %d (%s)" % [nominee.player_id, game_manager.role_name(nominee.role)])
		if state.game_phase == "election" and state.ineligible_co_consul_indices.size() > 0:
			lines.append("Blocked from co-consul this round: %s" % _player_list(state.ineligible_co_consul_indices))
		if state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0:
			var yes_str = _player_list(state.election_votes_yes)
			var no_str = _player_list(state.election_votes_no)
			lines.append("Voted YES: %s" % yes_str)
			lines.append("Voted NO: %s" % no_str)
			if state.election_passed:
				lines.append(">> Election PASSED")
			else:
				lines.append(">> Election FAILED")
		else:
			lines.append("Set each player's vote (Yes/No), then press Next step")
	elif state.game_phase == "election":
		lines.append("Choose a co-consul nominee to continue")
		if state.ineligible_co_consul_indices.size() > 0:
			lines.append("Blocked from co-consul this round: %s" % _player_list(state.ineligible_co_consul_indices))

	# Policy results (show after policy phase)
	if state.game_phase == "policy" and state.policy_enacted == null:
		lines.append("")
		lines.append("Policies drawn: %s" % _policy_list(state.policy_drawn_ids))
		lines.append("Policies discarded so far: %s" % _policy_list(state.policy_discarded_ids))
		var stage = game_manager.get_policy_discard_stage()
		if stage == "consul":
			lines.append("Consul must discard one policy")
		elif stage == "co_consul":
			lines.append("Co-Consul must discard one policy")
		else:
			lines.append("Preparing policy choices")

	if state.policy_enacted != null:
		var faction_name = "Patrician" if state.policy_enacted.faction == game_manager.Role.PATRICIAN else "Plebian"
		var discarded_str = ", ".join(state.policy_discarded_ids.map(func(id): return "Policy #%d" % id))
		lines.append("")
		lines.append("Policies discarded: %s" % discarded_str)
		lines.append("Policy enacted: #%d (%s)" % [state.policy_enacted.id, faction_name])
		lines.append("  Option A: %s" % state.policy_enacted.option_a_text)
		lines.append("  Option B: %s" % state.policy_enacted.option_b_text)

	# Spending results (show after spending phase)
	if state.game_phase == "spending" and state.spending_stage == "input":
		lines.append("")
		lines.append("Private spending input in progress")
		lines.append("Current player: Player %d" % state.spending_input_player_index)
	elif state.game_phase == "spending" and state.spending_stage == "handoff":
		lines.append("")
		lines.append("Pass device to next player")
	elif state.game_phase == "spending" and state.spending_stage == "resolved":
		lines.append("")
		lines.append("Private spending complete")

	if state.spending_winner != "":
		lines.append("")
		lines.append("Gold spent on Option A: %d" % state.spending_option_a_total)
		lines.append("Gold spent on Option B: %d" % state.spending_option_b_total)
		lines.append(">> Option %s wins!" % state.spending_winner)

	# Game over
	if state.game_phase == "game_over":
		if state.influence_patrician >= 5:
			lines.append("")
			lines.append("PATRICIANS WIN!")
		elif state.influence_plebian >= 5:
			lines.append("")
			lines.append("PLEBIANS WIN!")

	return "\n".join(lines)

func _player_list(ids: Array) -> String:
	if ids.size() == 0:
		return "none"
	var parts = []
	for id in ids:
		parts.append("Player %d" % id)
	return ", ".join(parts)

func _policy_list(ids: Array) -> String:
	if ids.size() == 0:
		return "none"
	var parts = []
	for id in ids:
		parts.append("Policy #%d" % id)
	return ", ".join(parts)

func _on_NextButton_pressed():
	print("Next button pressed")
	game_manager.progress()

func _on_nominee_button_pressed(nominee_index: int) -> void:
	game_manager.select_election_nominee(nominee_index)

func _on_vote_yes_pressed(player_id: int) -> void:
	game_manager.set_election_vote(player_id, true)

func _on_vote_no_pressed(player_id: int) -> void:
	game_manager.set_election_vote(player_id, false)

func _on_policy_discard_pressed(policy_id: int) -> void:
	game_manager.discard_policy_by_id(policy_id)

func _on_spending_split_pressed(amount_a: int) -> void:
	game_manager.set_spending_allocation(amount_a)

func _on_spending_ready_next_pressed() -> void:
	game_manager.advance_spending_turn()
