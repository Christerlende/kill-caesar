extends PanelContainer

# Roman-themed election panel for the player-facing UI.
# Shows nomination, per-player voting with checkboxes, and result reveal.

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_RED = Color(0.85, 0.15, 0.1, 1)
const COLOR_GREEN = Color(0.2, 0.8, 0.25, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)
const COLOR_DARK_BG = Color(0.08, 0.04, 0.03, 0.85)

var game_manager = null

# internal refs built in _ready
var _header_label: Label
var _consul_label: Label
var _nominee_label: Label
var _instruction_label: Label
var _nominee_section: VBoxContainer
var _voting_section: VBoxContainer
var _voter_grid: HBoxContainer
var _result_section: VBoxContainer
var _result_label: Label
var _result_breakdown: Label
var _continue_button: Button

var _proceed_button: Button

# state tracking to avoid rebuilds
var _last_nominee_index: int = -99
var _last_vote_signature: String = ""
var _last_phase: String = ""
var _showing_result: bool = false

func _ready():
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 12)
	margin.add_child(root_vbox)

	# Header
	_header_label = _make_label("SENATE ELECTION", 32, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root_vbox.add_child(_header_label)
	root_vbox.add_child(HSeparator.new())

	# Consul info
	_consul_label = _make_label("Consul: —", 20, COLOR_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	root_vbox.add_child(_consul_label)

	# Nominee section (nomination buttons appear here)
	_nominee_section = VBoxContainer.new()
	_nominee_section.add_theme_constant_override("separation", 8)
	root_vbox.add_child(_nominee_section)

	_nominee_label = _make_label("", 20, COLOR_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	_nominee_section.add_child(_nominee_label)

	root_vbox.add_child(HSeparator.new())

	# Voting section
	_voting_section = VBoxContainer.new()
	_voting_section.add_theme_constant_override("separation", 10)
	_voting_section.visible = false
	root_vbox.add_child(_voting_section)

	_instruction_label = _make_label("Citizens of Rome, cast your votes!", 18, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_voting_section.add_child(_instruction_label)

	_voter_grid = HBoxContainer.new()
	_voter_grid.alignment = BoxContainer.ALIGNMENT_CENTER
	_voter_grid.add_theme_constant_override("separation", 20)
	_voting_section.add_child(_voter_grid)

	# Result section
	_result_section = VBoxContainer.new()
	_result_section.add_theme_constant_override("separation", 8)
	_result_section.visible = false
	root_vbox.add_child(_result_section)

	_result_section.add_child(HSeparator.new())

	_result_label = _make_label("", 26, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_result_section.add_child(_result_label)

	_result_breakdown = _make_label("", 16, COLOR_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_result_breakdown.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_section.add_child(_result_breakdown)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	root_vbox.add_child(_continue_button)

	_proceed_button = Button.new()
	_proceed_button.text = "Proceed"
	_proceed_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_proceed_button.visible = false
	_proceed_button.pressed.connect(_on_proceed_pressed)
	root_vbox.add_child(_proceed_button)

func is_showing_result() -> bool:
	return _showing_result

func _process(_delta):
	if not game_manager:
		return
	var state = game_manager.state
	if not state:
		return
	# Keep updating when showing result even though phase has moved on
	if state.game_phase != "election" and not _showing_result:
		return
	if _showing_result:
		# Result is frozen on screen; just keep proceed button visible
		_proceed_button.visible = true
		return
	_update_consul_info(state)
	_update_nominee(state)
	_update_voting(state)
	_update_result(state)

func _update_consul_info(state) -> void:
	var consul = state.players[state.current_consul_index]
	_consul_label.text = "Consul: Player %d (%s)" % [consul.player_id, game_manager.role_name(consul.role)]

func _update_nominee(state) -> void:
	if state.election_nominee_index < 0:
		_nominee_label.text = "The Consul must nominate a Co-Consul"
		_voting_section.visible = false
		_result_section.visible = false
		_continue_button.visible = false
		if _last_nominee_index != -1:
			_rebuild_nominee_buttons(state)
			_last_nominee_index = -1
	else:
		var nominee = state.players[state.election_nominee_index]
		_nominee_label.text = "Nominated for Co-Consul: Player %d (%s)" % [nominee.player_id, game_manager.role_name(nominee.role)]
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
		b.text = "Player %d (%s)" % [player.player_id, game_manager.role_name(player.role)]
		b.pressed.connect(_on_nominee_selected.bind(idx))
		btn_row.add_child(b)
	_nominee_section.add_child(btn_row)

func _clear_nominee_buttons() -> void:
	var row = _nominee_section.get_node_or_null("NomineeBtnRow")
	if row:
		row.queue_free()

func _update_voting(state) -> void:
	if state.election_nominee_index < 0:
		return
	_voting_section.visible = true

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
		card_style.content_margin_left = 12.0
		card_style.content_margin_right = 12.0
		card_style.content_margin_top = 10.0
		card_style.content_margin_bottom = 10.0
		card.add_theme_stylebox_override("panel", card_style)
		card.custom_minimum_size = Vector2(120, 0)

		var col = VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		col.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(col)

		# Player name row with status icon
		var name_row = HBoxContainer.new()
		name_row.alignment = BoxContainer.ALIGNMENT_CENTER
		name_row.add_theme_constant_override("separation", 6)
		col.add_child(name_row)

		var name_label = Label.new()
		name_label.text = "Player %d" % player.player_id
		name_label.add_theme_font_size_override("font_size", 16)
		name_label.add_theme_color_override("font_color", COLOR_CREAM)
		name_row.add_child(name_label)

		# Green checkmark if voted
		if vote_state != -1:
			var check_icon = Label.new()
			check_icon.text = "✓"
			check_icon.add_theme_font_size_override("font_size", 18)
			check_icon.add_theme_color_override("font_color", COLOR_GREEN)
			name_row.add_child(check_icon)

		# Role subtitle
		var role_label = Label.new()
		role_label.text = game_manager.role_name(player.role)
		role_label.add_theme_font_size_override("font_size", 13)
		role_label.add_theme_color_override("font_color", COLOR_DIM)
		role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		col.add_child(role_label)

		if election_resolved:
			# Show locked results with crosses in correct checkbox
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
			# Interactive voting checkboxes
			var yes_cb = CheckBox.new()
			yes_cb.text = "Yes"
			yes_cb.button_pressed = (vote_state == 1)
			yes_cb.toggled.connect(_on_vote_toggled.bind(player_id, true))
			col.add_child(yes_cb)

			var no_cb = CheckBox.new()
			no_cb.text = "No"
			no_cb.button_pressed = (vote_state == 0)
			no_cb.toggled.connect(_on_vote_toggled.bind(player_id, false))
			col.add_child(no_cb)

		_voter_grid.add_child(card)

	_continue_button.visible = all_voted and not election_resolved

func _update_result(state) -> void:
	var election_resolved = state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0
	if not election_resolved:
		_result_section.visible = false
		return

	_result_section.visible = true
	if state.election_passed:
		_result_label.text = "THE SENATE HAS SPOKEN — VOTE PASSED"
		_result_label.add_theme_color_override("font_color", COLOR_GREEN)
	else:
		_result_label.text = "THE SENATE HAS SPOKEN — VOTE FAILED"
		_result_label.add_theme_color_override("font_color", COLOR_RED)

	var yes_names = []
	for pid in state.election_votes_yes:
		yes_names.append("Player %d" % pid)
	var no_names = []
	for pid in state.election_votes_no:
		no_names.append("Player %d" % pid)
	var yes_str = ", ".join(yes_names) if yes_names.size() > 0 else "none"
	var no_str = ", ".join(no_names) if no_names.size() > 0 else "none"
	_result_breakdown.text = "Yea: %s\nNay: %s" % [yes_str, no_str]

func reset_panel() -> void:
	_last_nominee_index = -99
	_last_vote_signature = ""
	_last_phase = ""
	_showing_result = false
	_voting_section.visible = false
	_result_section.visible = false
	_continue_button.visible = false
	_proceed_button.visible = false
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
	# Resolve the election, then freeze the panel to show the result
	game_manager.progress()
	_showing_result = true
	_continue_button.visible = false
	# Force one final update to display the result banner
	var state = game_manager.state
	if state:
		_last_vote_signature = ""
		_update_voting(state)
		_update_result(state)

func _on_proceed_pressed() -> void:
	_showing_result = false
	_proceed_button.visible = false

# --- helpers ---

func _make_label(text: String, font_size: int, color: Color, align: int) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
