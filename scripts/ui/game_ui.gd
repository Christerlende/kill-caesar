extends Control

var game_manager
var round_label: Label
var influence_label: Label
var consul_label: Label
var actor_prompt_label: Label
var nominee_buttons_container: HBoxContainer
var election_votes_container: VBoxContainer
var policy_discard_buttons_container: HBoxContainer
var spending_controls_container: VBoxContainer
var player_purses_label: Label
var gold_gain_label: Label
var phase_info_label: Label
var next_button: Button
var patrician_influence_bar: ProgressBar
var plebeian_influence_bar: ProgressBar
var _nominee_ui_key: String = ""
var _vote_ui_key: String = ""
var _policy_ui_key: String = ""
var _spending_ui_key: String = ""
var _spend_selected_option: String = "A"
var _spend_amount_draft: int = 0
var _spend_player_id_draft: int = -1
var _last_seen_round: int = -1
var _round_transition_message: String = ""
var _round_transition_time_left: float = 0.0
var election_panel = null
var policy_panel = null
var spending_panel = null
var result_panel = null
var round_start_panel = null
var info_panel = null
var assassination_tokens_panel = null
var _was_election_panel_active: bool = false
var _was_policy_panel_active: bool = false
var _was_spending_panel_active: bool = false
var _was_result_panel_active: bool = false
var _was_round_start_panel_active: bool = false

const ACTION_PANEL_OFFSET_LEFT: float = 375.0
const ACTION_PANEL_OFFSET_TOP: float = 210.0
const ACTION_PANEL_OFFSET_RIGHT: float = -18.0
const ACTION_PANEL_OFFSET_BOTTOM: float = -14.0

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

	# grab persistent HUD elements first
	var top_hud_panel = get_node_or_null("TopHudPanel")
	if top_hud_panel:
		top_hud_panel.clip_contents = true

	round_label = get_node_or_null("TopHudPanel/HudMargin/HudVBox/HudTopRow/RoundLabel")
	influence_label = get_node_or_null("TopHudPanel/HudMargin/HudVBox/HudTopRow/InfluenceLabel")
	consul_label = get_node_or_null("TopHudPanel/HudMargin/HudVBox/HudTopRow/ConsulLabel")
	actor_prompt_label = get_node_or_null("TopHudPanel/HudMargin/HudVBox/ActorPromptLabel")
	patrician_influence_bar = get_node_or_null("TopHudPanel/HudMargin/HudVBox/InfluenceBarsRow/PatricianBarBox/PatricianInfluenceBar")
	plebeian_influence_bar = get_node_or_null("TopHudPanel/HudMargin/HudVBox/InfluenceBarsRow/PlebeianBarBox/PlebeianInfluenceBar")

	# fallback to legacy nodes if HUD nodes are unavailable
	if not round_label:
		round_label = $VBoxContainer.get_node_or_null("RoundLabel")
	if not influence_label:
		influence_label = $VBoxContainer.get_node_or_null("InfluenceLabel")
	if not consul_label:
		consul_label = $VBoxContainer.get_node_or_null("ConsulLabel")
	if not actor_prompt_label:
		actor_prompt_label = $VBoxContainer.get_node_or_null("ActorPromptLabel")
	if actor_prompt_label:
		# Keep this as a single line to avoid temporary startup overlap with middle panel.
		actor_prompt_label.autowrap_mode = TextServer.AUTOWRAP_OFF

	# grab legacy/main control containers
	nominee_buttons_container = $VBoxContainer.get_node_or_null("NomineeButtonsContainer")
	election_votes_container = $VBoxContainer.get_node_or_null("ElectionVotesContainer")
	policy_discard_buttons_container = $VBoxContainer.get_node_or_null("PolicyDiscardButtonsContainer")
	spending_controls_container = $VBoxContainer.get_node_or_null("SpendingControlsContainer")
	player_purses_label = get_node_or_null("HiddenInfoPanel/HiddenInfoMargin/HiddenInfoRow/HiddenInfoLabel")
	gold_gain_label = get_node_or_null("HiddenInfoPanel/HiddenInfoMargin/HiddenInfoRow/GoldGainLabel")
	if not player_purses_label:
		player_purses_label = $VBoxContainer.get_node_or_null("PlayerPursesLabel")
	phase_info_label = $VBoxContainer.get_node_or_null("PhaseInfoLabel")
	next_button = $VBoxContainer.get_node_or_null("NextButton")
	print("labels:", round_label, influence_label, consul_label, actor_prompt_label, nominee_buttons_container, election_votes_container, policy_discard_buttons_container, spending_controls_container, player_purses_label, phase_info_label, "button", next_button)

	# hide legacy duplicated labels when persistent HUD is available
	var legacy_round = $VBoxContainer.get_node_or_null("RoundLabel")
	if legacy_round and legacy_round != round_label:
		legacy_round.visible = false
	var legacy_influence = $VBoxContainer.get_node_or_null("InfluenceLabel")
	if legacy_influence and legacy_influence != influence_label:
		legacy_influence.visible = false
	var legacy_consul = $VBoxContainer.get_node_or_null("ConsulLabel")
	if legacy_consul and legacy_consul != consul_label:
		legacy_consul.visible = false
	var legacy_actor = $VBoxContainer.get_node_or_null("ActorPromptLabel")
	if legacy_actor and legacy_actor != actor_prompt_label:
		legacy_actor.visible = false
	var legacy_hidden = $VBoxContainer.get_node_or_null("PlayerPursesLabel")
	if legacy_hidden and legacy_hidden != player_purses_label:
		legacy_hidden.visible = false

	# debug: list children
	print("GameUI children:", get_children())
	for c in get_children():
		print("  child", c.name, "type", c.get_class())

	# connect election panel
	election_panel = get_node_or_null("ElectionPanel")
	if election_panel:
		election_panel.game_manager = game_manager
		_apply_action_panel_frame(election_panel)
		election_panel.visible = false

	# connect policy panel
	policy_panel = get_node_or_null("PolicyPanel")
	if policy_panel:
		policy_panel.game_manager = game_manager
		_apply_action_panel_frame(policy_panel)
		policy_panel.visible = false

	# connect spending panel
	spending_panel = get_node_or_null("SpendingPanel")
	if spending_panel:
		spending_panel.game_manager = game_manager
		_apply_action_panel_frame(spending_panel)
		spending_panel.visible = false

	# connect result panel
	result_panel = get_node_or_null("ResultPanel")
	if result_panel:
		result_panel.game_manager = game_manager
		_apply_action_panel_frame(result_panel)
		result_panel.visible = false

	# connect round start panel (full screen overlay)
	round_start_panel = get_node_or_null("RoundStartPanel")
	if round_start_panel:
		round_start_panel.game_manager = game_manager
		_apply_action_panel_frame(round_start_panel)
		round_start_panel.visible = false

	# connect info panel (left sidebar)
	info_panel = get_node_or_null("InfoPanel")
	if info_panel:
		info_panel.game_manager = game_manager

	# create assassination tokens panel (dynamically)
	assassination_tokens_panel = preload("res://scripts/ui/assassination_tokens_panel.gd").new()
	assassination_tokens_panel.game_manager = game_manager
	assassination_tokens_panel.set_viewing_player(0)  # Default to player 0, updated per turn
	assassination_tokens_panel.visible = false
	if info_panel and info_panel.has_method("set_lower_sidebar_panel"):
		info_panel.set_lower_sidebar_panel(assassination_tokens_panel)
	else:
		add_child(assassination_tokens_panel)

	# hide legacy bottom info panel
	var hidden_info_panel = get_node_or_null("HiddenInfoPanel")
	if hidden_info_panel:
		hidden_info_panel.visible = false

	# connect button if available
	if next_button:
		next_button.connect("pressed", Callable(self, "_on_NextButton_pressed"))
		next_button.visible = false
	else:
		print("next_button is null")
	if phase_info_label:
		phase_info_label.visible = false

	_apply_influence_bar_styles()

func _apply_influence_bar_styles() -> void:
	if not patrician_influence_bar or not plebeian_influence_bar:
		return

	var bg_style = StyleBoxFlat.new()
	bg_style.bg_color = Color(0.12, 0.08, 0.06, 0.95)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.7, 0.55, 0.2, 0.7)
	bg_style.corner_radius_top_left = 6
	bg_style.corner_radius_top_right = 6
	bg_style.corner_radius_bottom_left = 6
	bg_style.corner_radius_bottom_right = 6

	var patrician_fill = StyleBoxFlat.new()
	patrician_fill.bg_color = Color(0.76, 0.16, 0.12, 0.95)
	patrician_fill.corner_radius_top_left = 5
	patrician_fill.corner_radius_top_right = 5
	patrician_fill.corner_radius_bottom_left = 5
	patrician_fill.corner_radius_bottom_right = 5

	var plebeian_fill = StyleBoxFlat.new()
	plebeian_fill.bg_color = Color(0.2, 0.36, 0.82, 0.95)
	plebeian_fill.corner_radius_top_left = 5
	plebeian_fill.corner_radius_top_right = 5
	plebeian_fill.corner_radius_bottom_left = 5
	plebeian_fill.corner_radius_bottom_right = 5

	patrician_influence_bar.add_theme_stylebox_override("background", bg_style)
	plebeian_influence_bar.add_theme_stylebox_override("background", bg_style)
	patrician_influence_bar.add_theme_stylebox_override("fill", patrician_fill)
	plebeian_influence_bar.add_theme_stylebox_override("fill", plebeian_fill)

func _process(_delta):
	if not game_manager:
		return
	var state = game_manager.state
	if not state:
		return
	if state.round_number != _last_seen_round:
		_last_seen_round = state.round_number
		if state.players.size() > 0:
			var round_consul = state.players[state.current_consul_index]
			_round_transition_message = "Round %d starts. Consul: %s" % [state.round_number, _player_name(round_consul.player_id)]
			_round_transition_time_left = 2.5
	if _round_transition_time_left > 0.0:
		_round_transition_time_left = max(_round_transition_time_left - _delta, 0.0)
	if round_label:
		round_label.text = "Round: %d" % state.round_number
	if influence_label:
		influence_label.text = "Patrician Influence: %d | Plebeian Influence: %d" % [state.influence_patrician, state.influence_plebian]
	if patrician_influence_bar and plebeian_influence_bar:
		var influence_target = max(1, game_manager.influence_to_win)
		patrician_influence_bar.max_value = influence_target
		plebeian_influence_bar.max_value = influence_target
		patrician_influence_bar.value = state.influence_patrician
		plebeian_influence_bar.value = state.influence_plebian
	if consul_label:
		var consul = state.players[state.current_consul_index]
		var co_consul_text = "Not chosen yet"
		if state.current_co_consul_index >= 0:
			var co_consul = state.players[state.current_co_consul_index]
			co_consul_text = _player_name(co_consul.player_id)
		consul_label.text = "Consul: %s | Co-Consul: %s" % [_player_name(consul.player_id), co_consul_text]
	if player_purses_label:
		player_purses_label.text = _build_player_purses_text(state)
	if gold_gain_label and state.players.size() > 0:
		var viewer_index = clamp(state.current_consul_index, 0, state.players.size() - 1)
		var viewer_role = state.players[viewer_index].role
		gold_gain_label.text = "Gold gain each round: %d" % _gold_gain_for_role(viewer_role)
	if actor_prompt_label:
		actor_prompt_label.text = _build_actor_prompt_text(state)
	if election_panel:
		_apply_action_panel_frame(election_panel)
	if policy_panel:
		_apply_action_panel_frame(policy_panel)
	if spending_panel:
		_apply_action_panel_frame(spending_panel)
	if result_panel:
		_apply_action_panel_frame(result_panel)
	# Toggle election panel vs legacy debug controls
	var in_election = state.game_phase == "election"
	var election_transition_active = false
	if election_panel:
		election_transition_active = election_panel.is_showing_result()
	var election_panel_active = in_election or election_transition_active
	if election_panel:
		election_panel.visible = election_panel_active
		if _was_election_panel_active and not election_panel_active:
			election_panel.reset_panel()
	_was_election_panel_active = election_panel_active
	if election_panel and election_panel_active:
		if nominee_buttons_container:
			nominee_buttons_container.visible = false
		if election_votes_container:
			election_votes_container.visible = false
	else:
		if nominee_buttons_container:
			nominee_buttons_container.visible = true
		if election_votes_container:
			election_votes_container.visible = true
	# Toggle policy panel vs legacy debug controls
	var in_policy = state.game_phase == "policy" and state.policy_enacted == null and not election_transition_active
	if policy_panel:
		policy_panel.visible = in_policy
		if _was_policy_panel_active and not in_policy:
			policy_panel.reset_panel()
	_was_policy_panel_active = in_policy
	if policy_panel and in_policy:
		if policy_discard_buttons_container:
			policy_discard_buttons_container.visible = false
	else:
		if policy_discard_buttons_container:
			policy_discard_buttons_container.visible = true

	# Toggle spending panel vs legacy spending controls
	var in_spending = state.game_phase == "spending"
	if spending_panel:
		spending_panel.visible = in_spending
		if _was_spending_panel_active and not in_spending:
			spending_panel.reset_panel()
	_was_spending_panel_active = in_spending
	if spending_controls_container:
		spending_controls_container.visible = not in_spending

	# Toggle result panel (keep visible during game_over so victory transition completes)
	var in_result = state.game_phase == "result" or state.game_phase == "game_over"
	if result_panel:
		var result_viewer_index = clamp(state.current_consul_index, 0, state.players.size() - 1)
		if state.game_phase == "result" and state.spending_input_player_index >= 0:
			result_viewer_index = clamp(state.spending_input_player_index, 0, state.players.size() - 1)
		result_panel.set_viewing_player(result_viewer_index)
		result_panel.visible = in_result
		if _was_result_panel_active and not in_result:
			result_panel.reset_panel()
	_was_result_panel_active = in_result

	# Toggle round start panel (full screen overlay)
	var in_round_start = state.game_phase == "round_start"
	if round_start_panel:
		if in_round_start and not round_start_panel.visible:
			var consul = state.players[state.current_consul_index]
			var consul_name = _player_name(consul.player_id)
			round_start_panel.show_round(state.round_number, consul_name)
		round_start_panel.visible = in_round_start
		if _was_round_start_panel_active and not in_round_start:
			round_start_panel.reset_panel()
	_was_round_start_panel_active = in_round_start

	# Toggle assassination tokens panel in the sidebar during active play, round start, and result
	var in_assassination_mode = state.game_phase in ["round_start", "election", "policy", "spending", "result"]
	if assassination_tokens_panel:
		var assassination_viewer_index = clamp(state.current_consul_index, 0, state.players.size() - 1)
		if state.game_phase in ["spending", "result"] and state.spending_input_player_index >= 0:
			assassination_viewer_index = clamp(state.spending_input_player_index, 0, state.players.size() - 1)
		assassination_tokens_panel.set_viewing_player(assassination_viewer_index)
		assassination_tokens_panel.visible = in_assassination_mode

	_update_nominee_buttons(state)
	_update_election_vote_buttons(state)
	_update_policy_discard_buttons(state)
	_update_spending_controls(state)

func _apply_action_panel_frame(panel: Control) -> void:
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = ACTION_PANEL_OFFSET_LEFT
	panel.offset_top = ACTION_PANEL_OFFSET_TOP
	panel.offset_right = ACTION_PANEL_OFFSET_RIGHT
	panel.offset_bottom = ACTION_PANEL_OFFSET_BOTTOM
	panel.custom_minimum_size = Vector2.ZERO

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
		b.text = "Choose Co-Consul: %s" % _player_name(candidate_index)
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
		label.text = "%s vote: %s" % [_player_name(player_id), vote_text]
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
	var ui_key = "%s|%s|%d|%s|%d" % [state.game_phase, state.spending_stage, state.spending_input_player_index, _spend_selected_option, _spend_amount_draft]
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
		if _spend_player_id_draft != player_id:
			_spend_player_id_draft = player_id
			_spend_selected_option = "A"
			_spend_amount_draft = 0
		var title = Label.new()
		title.text = "Private spending input: %s" % _player_name(player_id)
		spending_controls_container.add_child(title)
		var hint = Label.new()
		hint.text = "Choose one decree and how much gold to spend. Unspent gold stays in your purse."
		spending_controls_container.add_child(hint)

		var option_row = HBoxContainer.new()
		option_row.alignment = BoxContainer.ALIGNMENT_CENTER
		option_row.add_theme_constant_override("separation", 10)
		var a_btn = Button.new()
		a_btn.text = "Decree 1"
		a_btn.disabled = _spend_selected_option == "A"
		a_btn.pressed.connect(Callable(self, "_on_spending_option_selected").bind("A"))
		option_row.add_child(a_btn)
		var b_btn = Button.new()
		b_btn.text = "Decree 2"
		b_btn.disabled = _spend_selected_option == "B"
		b_btn.pressed.connect(Callable(self, "_on_spending_option_selected").bind("B"))
		option_row.add_child(b_btn)
		spending_controls_container.add_child(option_row)

		var spend_label = Label.new()
		spend_label.text = "Spend gold: %d" % _spend_amount_draft
		spend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spending_controls_container.add_child(spend_label)

		var adjust_row = HBoxContainer.new()
		adjust_row.alignment = BoxContainer.ALIGNMENT_CENTER
		adjust_row.add_theme_constant_override("separation", 14)
		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.disabled = _spend_amount_draft <= 0
		minus_btn.pressed.connect(Callable(self, "_on_spending_minus_pressed").bind(money))
		adjust_row.add_child(minus_btn)
		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.disabled = _spend_amount_draft >= money
		plus_btn.pressed.connect(Callable(self, "_on_spending_plus_pressed").bind(money))
		adjust_row.add_child(plus_btn)
		spending_controls_container.add_child(adjust_row)

		var purse_preview = Label.new()
		purse_preview.text = "Purse after payment: %d" % max(0, money - _spend_amount_draft)
		purse_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spending_controls_container.add_child(purse_preview)

		var commit_btn = Button.new()
		commit_btn.text = "Render Tribute"
		commit_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		commit_btn.pressed.connect(Callable(self, "_on_spending_pay_pressed"))
		spending_controls_container.add_child(commit_btn)
	elif state.spending_stage == "handoff":
		var handoff = Label.new()
		handoff.text = "Private entry saved. Pass to next player."
		spending_controls_container.add_child(handoff)
		var ready_button = Button.new()
		ready_button.text = "Ready for next player"
		ready_button.pressed.connect(Callable(self, "_on_spending_ready_next_pressed"))
		spending_controls_container.add_child(ready_button)
	elif state.spending_stage == "resolved":
		var done = Label.new()
		done.text = "All private spending captured. Totals are now public."
		spending_controls_container.add_child(done)
		var continue_button = Button.new()
		continue_button.text = "Continue"
		continue_button.pressed.connect(Callable(self, "_on_spending_continue_pressed"))
		spending_controls_container.add_child(continue_button)

func _build_player_purses_text(state) -> String:
	if state.players.size() == 0:
		return "No players"

	var viewer_index = clamp(state.current_consul_index, 0, state.players.size() - 1)
	if state.game_phase == "spending" and state.spending_stage == "input":
		viewer_index = clamp(state.spending_input_player_index, 0, state.players.size() - 1)
	var viewer = state.players[viewer_index]
	var viewer_role = viewer.role
	var own_gold = _visible_gold_for_player(state, viewer_index)

	if viewer_role == game_manager.Role.CAESAR:
		var patricians = []
		var plebeians = []
		for player in state.players:
			if player.player_id == viewer.player_id:
				continue
			if player.role == game_manager.Role.PATRICIAN:
				patricians.append(_player_name(player.player_id))
			elif player.role == game_manager.Role.PLEBIAN:
				plebeians.append(_player_name(player.player_id))
		var patrician_text = " & ".join(patricians) if patricians.size() > 0 else "none"
		var plebeian_text = ", ".join(plebeians) if plebeians.size() > 0 else "none"
		return "%s (Caesar) | Own gold: %d | Patricians: %s | Plebeians: %s" % [_player_name(viewer.player_id), own_gold, patrician_text, plebeian_text]

	if viewer_role == game_manager.Role.PATRICIAN:
		var other_patrician = "Unknown"
		for player in state.players:
			if player.player_id != viewer.player_id and player.role == game_manager.Role.PATRICIAN:
				other_patrician = _player_name(player.player_id)
				break
		return "%s (Patrician) | Own gold: %d | Allied Patrician: %s" % [_player_name(viewer.player_id), own_gold, other_patrician]

	return "%s (Plebeian) | Own gold: %d" % [_player_name(viewer.player_id), own_gold]

func _visible_gold_for_player(state, player_index: int) -> int:
	var current = state.players[player_index].money
	if spending_panel and spending_panel.is_preview_active() and spending_panel.preview_player_id() == player_index:
		var preview = spending_panel.preview_remaining_gold()
		if preview >= 0:
			return preview
	return current

func _gold_gain_for_role(role: int) -> int:
	if role == game_manager.Role.CAESAR:
		return 8
	if role == game_manager.Role.PATRICIAN:
		return 6
	return 4

func _build_actor_prompt_text(state) -> String:
	var actor_text = "Current actor: "
	match state.game_phase:
		"election":
			if state.election_nominee_index < 0:
				actor_text += "Consul chooses a co-consul nominee"
			elif not game_manager.are_election_votes_complete():
				actor_text += "All players vote Yes/No"
			else:
				actor_text += "Resolve election"
		"policy":
			var stage = game_manager.get_policy_discard_stage()
			if stage == "consul":
				actor_text += "Consul discards one policy"
			elif stage == "co_consul":
				actor_text += "Co-Consul discards one policy"
			else:
				actor_text += "Resolve policy"
		"spending":
			if state.spending_stage == "input":
				actor_text += "%s enters private spending" % _player_name(state.spending_input_player_index)
			elif state.spending_stage == "handoff":
				actor_text += "Pass to next player"
			elif state.spending_stage == "resolved":
				actor_text += "Resolve spending and continue"
			else:
				actor_text += "Spending"
		"round_end":
			actor_text += "Starting next round"
		_:
			actor_text += state.game_phase

	if _round_transition_time_left > 0.0 and _round_transition_message != "":
		return "%s | %s" % [_round_transition_message, actor_text]
	return actor_text

func _build_phase_text(state) -> String:
	var lines = ["Phase: %s" % state.game_phase]

	# Election results (show after election has run)
	if state.election_nominee_index >= 0:
		var nominee = state.players[state.election_nominee_index]
		lines.append("Nominee: %s" % _player_name(nominee.player_id))
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
		var faction_name = "Patrician" if state.policy_enacted.faction == game_manager.Role.PATRICIAN else "Plebeian"
		var discarded_str = ", ".join(state.policy_discarded_ids.map(func(id): return "Policy #%d" % id))
		lines.append("")
		lines.append("Policies discarded: %s" % discarded_str)
		lines.append("Policy enacted: #%d (%s)" % [state.policy_enacted.id, faction_name])
		lines.append("  Decree 1: %s" % state.policy_enacted.option_a_text)
		lines.append("  Decree 2: %s" % state.policy_enacted.option_b_text)

	# Spending results (show after spending phase)
	if state.game_phase == "spending" and state.spending_stage == "input":
		lines.append("")
		lines.append("Private spending input in progress")
		lines.append("Current player: %s" % _player_name(state.spending_input_player_index))
		lines.append("Each player chooses one decree and an amount to spend")
	elif state.game_phase == "spending" and state.spending_stage == "handoff":
		lines.append("")
		lines.append("Pass device to next player")
	elif state.game_phase == "spending" and state.spending_stage == "resolved":
		lines.append("")
		lines.append("Private spending complete")

	if state.spending_winner != "":
		lines.append("")
		lines.append("Gold spent on Decree 1: %d" % state.spending_option_a_total)
		lines.append("Gold spent on Decree 2: %d" % state.spending_option_b_total)
		lines.append(">> Decree %s wins!" % _decree_number_from_option_key(state.spending_winner))

	# Game over
	if state.game_phase == "game_over":
		if state.influence_patrician >= game_manager.influence_to_win:
			lines.append("")
			lines.append("PATRICIANS WIN!")
		elif state.influence_plebian >= game_manager.influence_to_win:
			lines.append("")
			lines.append("PLEBEIANS WIN!")

	return "\n".join(lines)

func _player_list(ids: Array) -> String:
	if ids.size() == 0:
		return "none"
	var parts = []
	for id in ids:
		parts.append(_player_name(id))
	return ", ".join(parts)

func _player_name(player_id: int) -> String:
	return game_manager.get_player_name(player_id)

func _policy_list(ids: Array) -> String:
	if ids.size() == 0:
		return "none"
	var parts = []
	for id in ids:
		parts.append("Policy #%d" % id)
	return ", ".join(parts)

func _decree_number_from_option_key(option_key: String) -> String:
	if option_key == "A":
		return "1"
	if option_key == "B":
		return "2"
	return option_key

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

func _on_spending_choice_pressed(option_key: String, spend_amount: int) -> void:
	game_manager.set_spending_allocation(option_key, spend_amount)

func _on_spending_ready_next_pressed() -> void:
	game_manager.advance_spending_turn()

func _on_spending_option_selected(option_key: String) -> void:
	_spend_selected_option = option_key
	_spending_ui_key = ""

func _on_spending_minus_pressed(max_money: int) -> void:
	_spend_amount_draft = clamp(_spend_amount_draft - 1, 0, max_money)
	_spending_ui_key = ""

func _on_spending_plus_pressed(max_money: int) -> void:
	_spend_amount_draft = clamp(_spend_amount_draft + 1, 0, max_money)
	_spending_ui_key = ""

func _on_spending_pay_pressed() -> void:
	game_manager.set_spending_allocation(_spend_selected_option, _spend_amount_draft)
	_spending_ui_key = ""

func _on_spending_continue_pressed() -> void:
	game_manager.progress()
	if game_manager.state.game_phase == "round_end":
		game_manager.progress()
