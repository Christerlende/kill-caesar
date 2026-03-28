extends PanelContainer

# Roman-themed election panel with three sections:
# Top: nomination info / header
# Middle: voting cards
# Bottom: election result + continue

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_RED = Color(0.85, 0.15, 0.1, 1)
const COLOR_GREEN = Color(0.2, 0.8, 0.25, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)
const COLOR_DARK_BG = Color(0.08, 0.04, 0.03, 0.85)

var game_manager = null

# Section containers
var _top_section: VBoxContainer
var _middle_section: VBoxContainer
var _bottom_section: VBoxContainer
var _sep1: HSeparator
var _sep2: HSeparator
var _middle_content: VBoxContainer
var _bottom_content: VBoxContainer

# Content refs
var _header_label: Label
var _consul_label: Label
var _nominee_label: Label
var _instruction_label: Label
var _nominee_btn_container: VBoxContainer
var _voter_grid: HBoxContainer
var _result_label: Label
var _result_breakdown: Label
var _continue_button: Button

# state tracking
var _last_nominee_index: int = -99
var _last_vote_signature: String = ""
var _last_phase: String = ""
var _showing_result: bool = false
var _result_auto_advance_time_left: float = 0.0
var _auto_resolve_queued: bool = false
var _result_reveal_played: bool = false
var _voting_reveal_played: bool = false

const RESULT_TRANSITION_SECONDS: float = 20.0

func _ready():
	clip_contents = true

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 14)
	add_child(margin)

	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 0)
	margin.add_child(root)

	# ── Top Section: Header + Nomination ──
	_top_section = VBoxContainer.new()
	_top_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_top_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_top_section.alignment = BoxContainer.ALIGNMENT_BEGIN
	_top_section.add_theme_constant_override("separation", 10)
	root.add_child(_top_section)

	_header_label = _make_label("SENATE ELECTION", 28, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_top_section.add_child(_header_label)

	_consul_label = _make_label("Consul: —", 18, COLOR_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_top_section.add_child(_consul_label)

	_nominee_label = _make_label("", 18, COLOR_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_top_section.add_child(_nominee_label)

	_nominee_btn_container = VBoxContainer.new()
	_nominee_btn_container.add_theme_constant_override("separation", 8)
	_top_section.add_child(_nominee_btn_container)

	# ── Separator 1 ──
	_sep1 = HSeparator.new()
	root.add_child(_sep1)

	# ── Middle Section: Voting ──
	_middle_section = VBoxContainer.new()
	_middle_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_middle_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_middle_section.alignment = BoxContainer.ALIGNMENT_BEGIN
	_middle_section.add_theme_constant_override("separation", 0)
	root.add_child(_middle_section)

	_middle_content = VBoxContainer.new()
	_middle_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_middle_content.add_theme_constant_override("separation", 10)
	_middle_content.visible = false
	_middle_section.add_child(_middle_content)

	_instruction_label = _make_label("Citizens of Rome, cast your votes!", 18, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_middle_content.add_child(_instruction_label)

	_voter_grid = HBoxContainer.new()
	_voter_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_voter_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	_voter_grid.add_theme_constant_override("separation", 12)
	_middle_content.add_child(_voter_grid)

	# ── Separator 2 ──
	_sep2 = HSeparator.new()
	root.add_child(_sep2)

	# ── Bottom Section: Result ──
	_bottom_section = VBoxContainer.new()
	_bottom_section.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bottom_section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_section.alignment = BoxContainer.ALIGNMENT_BEGIN
	_bottom_section.add_theme_constant_override("separation", 0)
	root.add_child(_bottom_section)

	_bottom_content = VBoxContainer.new()
	_bottom_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_content.add_theme_constant_override("separation", 10)
	_bottom_content.visible = false
	_bottom_section.add_child(_bottom_content)

	_result_label = _make_label("", 26, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_bottom_content.add_child(_result_label)

	_result_breakdown = _make_label("", 16, COLOR_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_result_breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bottom_content.add_child(_result_breakdown)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.add_theme_color_override("font_color", COLOR_CREAM)
	_continue_button.add_theme_color_override("font_focus_color", COLOR_CREAM)
	_continue_button.add_theme_color_override("font_hover_color", COLOR_CREAM)
	_continue_button.add_theme_color_override("font_pressed_color", COLOR_CREAM)
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
	_continue_button.add_theme_stylebox_override("normal", cs)
	_continue_button.add_theme_stylebox_override("focus", cs)
	_continue_button.add_theme_stylebox_override("pressed", cs)
	_continue_button.add_theme_stylebox_override("hover", cs)
	_bottom_content.add_child(_continue_button)

func is_showing_result() -> bool:
	return _showing_result

func _process(_delta):
	if not game_manager:
		return
	var state = game_manager.state
	if not state:
		return
	if state.game_phase != "election" and not _showing_result:
		return
	if _showing_result:
		_result_auto_advance_time_left = max(_result_auto_advance_time_left - _delta, 0.0)
		_update_continue_button_text()
		_update_result(state)
		if _result_auto_advance_time_left <= 0.0:
			_advance_after_result()
		return
	_update_consul_info(state)
	_update_nominee(state)
	_update_voting(state)
	_update_result(state)

func _update_consul_info(state) -> void:
	var consul = state.players[state.current_consul_index]
	_consul_label.text = "Consul: %s" % _player_name(consul.player_id)

func _update_nominee(state) -> void:
	if state.election_nominee_index < 0:
		_nominee_label.text = "The consul must nominate a co-consul."
		_middle_content.visible = false
		_bottom_content.visible = false
		_voting_reveal_played = false
		_continue_button.visible = false
		if _last_nominee_index != -1:
			_rebuild_nominee_buttons(state)
			_last_nominee_index = -1
	else:
		var nominee = state.players[state.election_nominee_index]
		_nominee_label.text = "Nominated for co-consul: %s" % _player_name(nominee.player_id)
		if _last_nominee_index < 0:
			_clear_nominee_buttons()
			_last_nominee_index = state.election_nominee_index

func _rebuild_nominee_buttons(state) -> void:
	_clear_nominee_buttons()
	var candidates = game_manager.get_nominee_candidates()
	if candidates.size() == 0:
		return
	var btn_row = HBoxContainer.new()
	btn_row.name = "NomineeBtnRow"
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 12)
	for idx in candidates:
		var player = state.players[idx]
		var b = Button.new()
		b.text = _player_name(player.player_id)
		b.pressed.connect(_on_nominee_selected.bind(idx))
		btn_row.add_child(b)
	_nominee_btn_container.add_child(btn_row)

func _clear_nominee_buttons() -> void:
	var row = _nominee_btn_container.get_node_or_null("NomineeBtnRow")
	if row:
		row.queue_free()

func _update_voting(state) -> void:
	if state.election_nominee_index < 0:
		return
	if not _middle_content.visible:
		_middle_content.visible = true
		if not _voting_reveal_played:
			_play_voting_reveal_animation()

	var sig = ""
	for v in state.election_vote_inputs:
		sig += str(v) + ","
	if sig == _last_vote_signature and _last_phase == state.game_phase:
		return
	_last_vote_signature = sig
	_last_phase = state.game_phase

	for child in _voter_grid.get_children():
		child.queue_free()

	var all_voted = game_manager.are_election_votes_complete()
	var election_resolved = state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0
	var player_count = max(1, state.players.size())
	var row_gap = 10
	var panel_inner_width = int(size.x) if size.x > 0 else 600
	var usable_width = panel_inner_width - 64
	var card_width = int(floor(float(usable_width - row_gap * (player_count - 1)) / float(player_count)))
	card_width = clamp(card_width, 80, 130)
	_voter_grid.add_theme_constant_override("separation", row_gap)

	for player_id in range(state.players.size()):
		var player = state.players[player_id]
		var vote_state = state.election_vote_inputs[player_id]

		var card = PanelContainer.new()
		var card_style = StyleBoxFlat.new()
		card_style.bg_color = COLOR_DARK_BG
		card_style.border_width_left = 1
		card_style.border_width_top = 1
		card_style.border_width_right = 1
		card_style.border_width_bottom = 1
		card_style.border_color = Color(0.5, 0.38, 0.12, 0.6)
		card_style.corner_radius_top_left = 6
		card_style.corner_radius_top_right = 6
		card_style.corner_radius_bottom_left = 6
		card_style.corner_radius_bottom_right = 6
		card_style.content_margin_left = 10.0
		card_style.content_margin_right = 10.0
		card_style.content_margin_top = 8.0
		card_style.content_margin_bottom = 8.0
		card.add_theme_stylebox_override("panel", card_style)
		card.custom_minimum_size = Vector2(card_width, 0)

		var col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(col)

		var name_row = HBoxContainer.new()
		name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		name_row.add_theme_constant_override("separation", 6)
		col.add_child(name_row)

		var name_label = Label.new()
		name_label.text = _player_name(player.player_id)
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", COLOR_CREAM)
		name_row.add_child(name_label)

		if vote_state != -1:
			var check_icon = Label.new()
			check_icon.text = "✓"
			check_icon.add_theme_font_size_override("font_size", 18)
			check_icon.add_theme_color_override("font_color", COLOR_GREEN)
			name_row.add_child(check_icon)

		if election_resolved:
			var yes_cb = CheckBox.new()
			yes_cb.text = "Yes"
			yes_cb.disabled = true
			yes_cb.button_pressed = (vote_state == 1)
			if vote_state == 1:
				yes_cb.add_theme_color_override("font_color", COLOR_GREEN)
			col.add_child(yes_cb)

			var no_cb = CheckBox.new()
			no_cb.text = "No"
			no_cb.disabled = true
			no_cb.button_pressed = (vote_state == 0)
			if vote_state == 0:
				no_cb.add_theme_color_override("font_color", COLOR_RED)
			col.add_child(no_cb)
		else:
			var vote_group = ButtonGroup.new()
			vote_group.allow_unpress = false

			var yes_cb = CheckBox.new()
			yes_cb.text = "Yes"
			yes_cb.button_pressed = (vote_state == 1)
			yes_cb.button_group = vote_group
			yes_cb.toggled.connect(_on_vote_toggled.bind(player_id, true))
			col.add_child(yes_cb)

			var no_cb = CheckBox.new()
			no_cb.text = "No"
			no_cb.button_pressed = (vote_state == 0)
			no_cb.button_group = vote_group
			no_cb.toggled.connect(_on_vote_toggled.bind(player_id, false))
			col.add_child(no_cb)

		_voter_grid.add_child(card)

	_continue_button.visible = _showing_result
	if all_voted and not election_resolved and not _auto_resolve_queued and not _showing_result:
		_auto_resolve_queued = true
		call_deferred("_resolve_election_and_show_result")

func _update_result(state) -> void:
	var election_resolved = state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0
	if not election_resolved:
		_bottom_content.visible = false
		_result_reveal_played = false
		return

	_bottom_content.visible = true
	if state.election_passed:
		_result_label.text = "Election successful"
		_result_label.add_theme_color_override("font_color", COLOR_GREEN)
	else:
		_result_label.text = "Election unsuccessful"
		_result_label.add_theme_color_override("font_color", COLOR_RED)

	var yes_names = []
	for pid in state.election_votes_yes:
		yes_names.append(_player_name(pid))
	var no_names = []
	for pid in state.election_votes_no:
		no_names.append(_player_name(pid))
	var yes_str = ", ".join(yes_names) if yes_names.size() > 0 else "none"
	var no_str = ", ".join(no_names) if no_names.size() > 0 else "none"
	var transition_text = _build_transition_text(state)
	var details = "%s\n\nYea: %s\nNay: %s" % [transition_text, yes_str, no_str]
	_result_breakdown.text = details

func _build_transition_text(state) -> String:
	var consul_name = _player_name(state.current_consul_index)
	var nominee_name = _player_name(state.election_nominee_index)
	if state.election_passed:
		var co_consul_name = _player_name(state.current_co_consul_index) if state.current_co_consul_index >= 0 else nominee_name
		return "%s and %s step into power as consul and co-consul." % [consul_name, co_consul_name]
	return "%s and %s do not gain power. The senate rejects their rise this round." % [consul_name, nominee_name]

func reset_panel() -> void:
	_last_nominee_index = -99
	_last_vote_signature = ""
	_last_phase = ""
	_showing_result = false
	_result_auto_advance_time_left = 0.0
	_auto_resolve_queued = false
	_result_reveal_played = false
	_voting_reveal_played = false
	_middle_content.visible = false
	_middle_content.modulate = Color(1, 1, 1, 1)
	_bottom_content.visible = false
	_bottom_content.modulate = Color(1, 1, 1, 1)
	_continue_button.visible = false
	_clear_nominee_buttons()
	for child in _voter_grid.get_children():
		child.queue_free()

# --- callbacks ---

func _on_nominee_selected(nominee_index: int) -> void:
	game_manager.select_election_nominee(nominee_index)

func _on_vote_toggled(is_on: bool, player_id: int, is_yes: bool) -> void:
	if is_on:
		game_manager.set_election_vote(player_id, is_yes)

func _on_continue_pressed() -> void:
	if _showing_result:
		_advance_after_result()
		return
	_resolve_election_and_show_result()

func _advance_after_result() -> void:
	if not _showing_result:
		return
	_showing_result = false
	_result_auto_advance_time_left = 0.0
	_continue_button.visible = false
	if game_manager and game_manager.state and game_manager.state.game_phase == "round_end":
		game_manager.progress()

func _resolve_election_and_show_result() -> void:
	_auto_resolve_queued = false
	if not game_manager or not game_manager.state:
		return
	var state = game_manager.state
	if state.game_phase != "election":
		return
	var election_resolved = state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0
	if election_resolved:
		return
	if not game_manager.are_election_votes_complete():
		return
	game_manager.progress()
	_showing_result = true
	_result_auto_advance_time_left = RESULT_TRANSITION_SECONDS
	_continue_button.visible = true
	_update_continue_button_text()
	state = game_manager.state
	if state:
		_last_vote_signature = ""
		_update_voting(state)
		_update_result(state)
		_play_result_reveal_animation()

func _play_result_reveal_animation() -> void:
	if not _bottom_content or _result_reveal_played:
		return
	_result_reveal_played = true
	_bottom_content.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(_bottom_content, "modulate:a", 1.0, 0.50).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _play_voting_reveal_animation() -> void:
	if not _middle_content:
		return
	_voting_reveal_played = true
	_middle_content.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	tween.tween_property(_middle_content, "modulate:a", 1.0, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _update_continue_button_text() -> void:
	if not _continue_button or not _showing_result:
		return
	_continue_button.text = "Continue (%d)" % int(ceil(_result_auto_advance_time_left))

# --- helpers ---

func _make_label(text: String, font_size: int, color: Color, align: int) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _player_name(player_id: int) -> String:
	return game_manager.get_player_name(player_id)
