extends PanelContainer

const Role = preload("res://scripts/data/role.gd").Role
const GameManager = preload("res://scripts/game/game_manager.gd")

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)
const COLOR_RED_FACTION = Color(0.72, 0.14, 0.1, 0.85)
const COLOR_BLUE_FACTION = Color(0.15, 0.3, 0.7, 0.85)
const COLOR_CHAOS_FACTION = Color(0.38, 0.36, 0.34, 0.92)

var game_manager = null

var _left_scroll: ScrollContainer
var _history_list: VBoxContainer
var _right_box: VBoxContainer
var _continue_button: Button
var _last_ui_key: String = ""

# Fade-in animation state
const FADE_DELAY: float = 1.0
const FADE_DURATION: float = 1.0

var _animation_started: bool = false
var _influence_applied: bool = false
var _decree_applied: bool = false
var _influence_item: Label = null
var _decree_item: Label = null
var _threat_item: Label = null
var _deadlock_item: Label = null
var _viewing_player_id: int = -1
var _fade_tween: Tween = null

func _ready() -> void:
	clip_contents = true

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 0)
	margin.add_child(root_vbox)

	var split = HBoxContainer.new()
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 18)
	root_vbox.add_child(split)

	# ── Left half: round history ──
	var left_panel = VBoxContainer.new()
	left_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.size_flags_stretch_ratio = 1.0
	left_panel.add_theme_constant_override("separation", 10)
	split.add_child(left_panel)

	var history_title = Label.new()
	history_title.text = "ROUND HISTORY"
	history_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	history_title.add_theme_font_size_override("font_size", 22)
	history_title.add_theme_color_override("font_color", COLOR_GOLD)
	left_panel.add_child(history_title)

	left_panel.add_child(HSeparator.new())

	_left_scroll = ScrollContainer.new()
	_left_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left_panel.add_child(_left_scroll)

	_history_list = VBoxContainer.new()
	_history_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_list.add_theme_constant_override("separation", 14)
	_left_scroll.add_child(_history_list)

	# ── Right half: round results ──
	var right_panel = VBoxContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 1.0
	right_panel.add_theme_constant_override("separation", 10)
	split.add_child(right_panel)

	# Spacer to push items down from the top
	var top_spacer = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, 40)
	right_panel.add_child(top_spacer)

	_right_box = VBoxContainer.new()
	_right_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_right_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_right_box.add_theme_constant_override("separation", 32)
	right_panel.add_child(_right_box)

	# ── Continue button: centered below the split, spanning full width ──
	_continue_button = _build_continue_button()
	_continue_button.visible = false
	var btn_container = HBoxContainer.new()
	btn_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_container.add_child(_continue_button)
	root_vbox.add_child(btn_container)

func _process(_delta: float) -> void:
	if not game_manager:
		return
	var state = game_manager.state
	if not state or state.game_phase != "result":
		return

	var ui_key = "result|%d|%d" % [state.round_history.size(), _viewing_player_id]
	if ui_key == _last_ui_key:
		return
	_last_ui_key = ui_key

	_rebuild_history(state)

	if not _animation_started:
		_start_fade_in_sequence(state)

func reset_panel() -> void:
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	_last_ui_key = ""
	_animation_started = false
	_influence_applied = false
	_decree_applied = false
	_influence_item = null
	_decree_item = null
	_threat_item = null
	_deadlock_item = null
	_continue_button.visible = false
	for child in _history_list.get_children():
		child.queue_free()
	for child in _right_box.get_children():
		child.queue_free()

func set_viewing_player(player_id: int) -> void:
	if _viewing_player_id == player_id:
		return
	_viewing_player_id = player_id
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null
	_last_ui_key = ""
	_animation_started = false
	_continue_button.visible = false
	_influence_item = null
	_decree_item = null
	_threat_item = null
	_deadlock_item = null
	for child in _right_box.get_children():
		child.queue_free()

func _start_fade_in_sequence(state) -> void:
	_animation_started = true
	if _fade_tween:
		_fade_tween.kill()
		_fade_tween = null

	# Clear right box
	for child in _right_box.get_children():
		child.queue_free()

	var items: Array = []
	var skip_influence_and_decree = state.greed_round or state.deadlock_round

	# Item 1: Influence gain (skipped on Greed treasury-failure rounds)
	var policy = state.policy_enacted
	if not skip_influence_and_decree:
		var faction_name = "Plebeian" if policy != null and policy.faction == Role.PLEBIAN else "Patrician"
		_influence_item = Label.new()
		_influence_item.text = "+1 %s Influence" % faction_name
		_influence_item.add_theme_font_size_override("font_size", 22)
		_influence_item.add_theme_color_override("font_color", COLOR_CREAM)
		_influence_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_influence_item.modulate = Color(1, 1, 1, 0)
		_right_box.add_child(_influence_item)
		items.append({"node": _influence_item, "kind": "influence"})
	else:
		_influence_item = null
		var greed_note = Label.new()
		greed_note.text = "The treasury failed Rome. No decree takes effect this round." if state.greed_round else "The senate deadlocked. No decree takes effect this round."
		greed_note.add_theme_font_size_override("font_size", 20)
		greed_note.add_theme_color_override("font_color", COLOR_DIM)
		greed_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		greed_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		greed_note.modulate = Color(1, 1, 1, 0)
		_right_box.add_child(greed_note)
		items.append({"node": greed_note, "kind": "greed_note"})

	# Item 2: Decree result text (if policy enacted and not greed round)
	if not skip_influence_and_decree and policy != null:
		var result_text = ""
		if state.spending_winner == "A":
			result_text = policy.option_a_result_text
		else:
			result_text = policy.option_b_result_text

		if result_text != "":
			_decree_item = Label.new()
			_decree_item.text = result_text
			_decree_item.add_theme_font_size_override("font_size", 20)
			_decree_item.add_theme_color_override("font_color", COLOR_CREAM)
			_decree_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_decree_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_decree_item.modulate = Color(1, 1, 1, 0)
			_right_box.add_child(_decree_item)
			items.append({"node": _decree_item, "kind": "decree"})
	else:
		_decree_item = null
	if state.deadlock_round:
		_deadlock_item = Label.new()
		_deadlock_item.text = _deadlock_effect_result_text(state.last_deadlock_effect_id)
		_deadlock_item.add_theme_font_size_override("font_size", 20)
		_deadlock_item.add_theme_color_override("font_color", COLOR_CREAM)
		_deadlock_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_deadlock_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_deadlock_item.modulate = Color(1, 1, 1, 0)
		_right_box.add_child(_deadlock_item)
		items.append({"node": _deadlock_item, "kind": "deadlock"})
	else:
		_deadlock_item = null

	var caesar_line = _build_caesar_override_line(state)
	if caesar_line != "":
		var caesar_item = Label.new()
		caesar_item.text = caesar_line
		caesar_item.add_theme_font_size_override("font_size", 24)
		caesar_item.add_theme_color_override("font_color", COLOR_GOLD)
		caesar_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caesar_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caesar_item.modulate = Color(1, 1, 1, 0)
		_right_box.add_child(caesar_item)
		items.append({"node": caesar_item, "kind": "caesar"})

	var assassination_message = _build_private_assassination_message(state)
	if assassination_message != "":
		_threat_item = Label.new()
		_threat_item.text = assassination_message
		_threat_item.add_theme_font_size_override("font_size", 20)
		_threat_item.add_theme_color_override("font_color", COLOR_RED_FACTION)
		_threat_item.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_threat_item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_threat_item.modulate = Color(1, 1, 1, 0)
		_right_box.add_child(_threat_item)
		items.append({"node": _threat_item, "kind": "threat"})

	# Build the tween chain
	var tween = create_tween()
	_fade_tween = tween
	tween.finished.connect(_on_fade_sequence_finished)

	for i in range(items.size()):
		var item = items[i]
		tween.tween_interval(FADE_DELAY)
		tween.tween_property(item.node, "modulate:a", 1.0, FADE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_callback(_on_item_visible.bind(item.kind))

	# After last item is fully visible, wait 2 more seconds then show continue button
	tween.tween_interval(FADE_DELAY)
	tween.tween_callback(_show_continue_button)

func _on_fade_sequence_finished() -> void:
	_fade_tween = null

func _on_item_visible(item_index: String) -> void:
	if item_index == "greed_note":
		pass
	elif item_index == "influence" and not _influence_applied:
		_influence_applied = true
		if game_manager and game_manager.state and game_manager.state.policy_enacted:
			game_manager.apply_policy_influence(game_manager.state.policy_enacted)
			game_manager.check_win_condition()
	elif item_index == "decree" and not _decree_applied:
		_decree_applied = true
		if game_manager and game_manager.state and game_manager.state.policy_enacted:
			game_manager.apply_enacted_decree_effect(game_manager.state.policy_enacted, game_manager.state.spending_winner)

func _build_caesar_override_line(state) -> String:
	## Predict (at fade-build time) whether a Caesar override will fire this round:
	## Caesar must be alive with >= CAESAR_POLICIES_TO_WIN successful co-consul elections,
	## the round must enact a policy (+1 influence), and that influence must push a faction
	## to >= influence_to_win.
	if state == null or state.greed_round or state.deadlock_round:
		return ""
	var policy = state.policy_enacted
	if policy == null:
		return ""
	var caesar = null
	for p in state.players:
		if p.role == Role.CAESAR and not p.is_dead:
			caesar = p
			break
	if caesar == null or caesar.co_consul_count < 3:
		return ""
	var faction_name: String = ""
	if policy.faction == Role.PATRICIAN:
		if state.influence_patrician + 1 >= GameManager.influence_to_win:
			faction_name = "Patricians"
	else:
		if state.influence_plebian + 1 >= GameManager.influence_to_win:
			faction_name = "Plebeians"
	if faction_name == "":
		return ""
	return "The %s had already begun their triumph — yet in the eleventh hour, Caesar seizes the final vote, and Rome kneels before him alone." % faction_name

func _build_private_assassination_message(state) -> String:
	if not game_manager:
		return ""
	if _viewing_player_id < 0 or _viewing_player_id >= state.players.size():
		return ""
	var new_tokens = game_manager.count_tokens_placed_this_round(_viewing_player_id)
	if new_tokens <= 0:
		return ""
	var total_tokens = game_manager.get_tokens_on_player(_viewing_player_id).size()
	if total_tokens >= 3:
		return "Three blades now bear your name. Before another dawn, Rome will find your body."
	if total_tokens == 2:
		return "A second assassin shadows your steps. One more blade will end your cause."
	return "Word reaches you in secret: an assassin has been loosed against you."

func _is_game_over() -> bool:
	return game_manager and game_manager.state and game_manager.state.game_phase == "game_over"

func _deadlock_effect_result_text(effect_id: int) -> String:
	match effect_id:
		GameManager.DEADLOCK_ASSASSINS_ROOFTOPS:
			return "Assassins climbed the rooftops; one representative gained an assassination token."
		GameManager.DEADLOCK_SECRET_LOBBY_PAYOUT:
			return "A hidden lobbying purse changed hands; one representative gained 10 gold."
		GameManager.DEADLOCK_COSTLY_LOBBYING:
			return "Backroom lobbying took its toll; two representatives lost 5 gold each."
		GameManager.DEADLOCK_ASSASSINS_HUNT:
			return "Assassins marked a new target in the dark; the hunt grows deadlier."
		_:
			return "The deadlock sends ripples of fear through the senate."

func _show_continue_button() -> void:
	if _is_game_over():
		# Auto-transition to victory screen after a short pause
		var game_over_tween = create_tween()
		game_over_tween.tween_interval(1.5)
		game_over_tween.tween_callback(_go_to_victory_screen)
		return
	_continue_button.visible = true
	_continue_button.modulate = Color(1, 1, 1, 0)
	var button_tween = create_tween()
	button_tween.tween_property(_continue_button, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _go_to_victory_screen() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/end_game.tscn")

func _build_continue_button() -> Button:
	var btn = Button.new()
	btn.text = "Continue to next round"
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(_on_continue_pressed)
	btn.add_theme_color_override("font_color", COLOR_CREAM)
	btn.add_theme_color_override("font_focus_color", COLOR_CREAM)
	btn.add_theme_color_override("font_hover_color", COLOR_CREAM)
	btn.add_theme_color_override("font_pressed_color", COLOR_CREAM)
	var cs = StyleBoxFlat.new()
	cs.bg_color = Color(0.14, 0.62, 0.18, 0.95)
	cs.border_width_left = 1
	cs.border_width_top = 1
	cs.border_width_right = 1
	cs.border_width_bottom = 1
	cs.border_color = Color(0.78, 0.9, 0.78, 0.7)
	cs.corner_radius_top_left = 6
	cs.corner_radius_top_right = 6
	cs.corner_radius_bottom_left = 6
	cs.corner_radius_bottom_right = 6
	cs.content_margin_left = 16
	cs.content_margin_right = 16
	cs.content_margin_top = 8
	cs.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", cs)
	btn.add_theme_stylebox_override("focus", cs)
	btn.add_theme_stylebox_override("pressed", cs)
	btn.add_theme_stylebox_override("hover", cs)
	return btn

func _rebuild_history(state) -> void:
	for child in _history_list.get_children():
		child.queue_free()

	for entry in state.round_history:
		var row = VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		# Round number
		var round_label = Label.new()
		round_label.text = "Round %d" % entry.round_number
		round_label.add_theme_font_size_override("font_size", 18)
		round_label.add_theme_color_override("font_color", COLOR_CREAM)
		row.add_child(round_label)

		# Faction pill
		var pill = PanelContainer.new()
		var pill_style = StyleBoxFlat.new()
		var is_chaos = entry.get("chaos", false) or str(entry.get("faction", "")) == "Chaos"
		var is_deadlock = entry.get("deadlock", false) or str(entry.get("faction", "")) == "Draw"
		var is_plebeian = not is_chaos and not is_deadlock and entry.faction == "Plebeian"
		if is_chaos or is_deadlock:
			pill_style.bg_color = COLOR_CHAOS_FACTION
		else:
			pill_style.bg_color = COLOR_BLUE_FACTION if is_plebeian else COLOR_RED_FACTION
		pill_style.corner_radius_top_left = 10
		pill_style.corner_radius_top_right = 10
		pill_style.corner_radius_bottom_left = 10
		pill_style.corner_radius_bottom_right = 10
		pill_style.content_margin_left = 10.0
		pill_style.content_margin_right = 10.0
		pill_style.content_margin_top = 4.0
		pill_style.content_margin_bottom = 4.0
		pill.add_theme_stylebox_override("panel", pill_style)
		pill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN

		var pill_label = Label.new()
		pill_label.text = "Chaos" if is_chaos else ("Draw" if is_deadlock else ("%s Policy" % entry.faction))
		pill_label.add_theme_font_size_override("font_size", 14)
		pill_label.add_theme_color_override("font_color", COLOR_CREAM)
		pill.add_child(pill_label)
		row.add_child(pill)

		# Consul / Co-consul
		var consul_label = Label.new()
		consul_label.text = "Consul: %s" % entry.consul_name
		consul_label.add_theme_font_size_override("font_size", 13)
		consul_label.add_theme_color_override("font_color", COLOR_DIM)
		row.add_child(consul_label)

		var co_consul_label = Label.new()
		co_consul_label.text = "Co-consul: %s" % entry.co_consul_name
		co_consul_label.add_theme_font_size_override("font_size", 13)
		co_consul_label.add_theme_color_override("font_color", COLOR_DIM)
		row.add_child(co_consul_label)

		_history_list.add_child(row)

		# Separator between entries
		_history_list.add_child(HSeparator.new())

func _on_continue_pressed() -> void:
	if game_manager:
		game_manager.progress()
		if game_manager.state.game_phase == "round_end":
			game_manager.progress()
		_last_ui_key = ""
