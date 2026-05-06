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
## Offline: use game_manager.hotseat_viewer_seat (shared with policy secrecy UI).
var _hotseat_ai_nominate_attempted: bool = false
var _last_nominee_button_key: String = ""
var _last_device_row_key: String = ""
var _voter_grid: HBoxContainer
var _result_label: Label
var _result_breakdown: Label
var _continue_button: Button
var _result_countdown_label: Label

# state tracking
var _last_nominee_index: int = -99
var _last_vote_signature: String = ""
var _last_phase: String = ""
var _showing_result: bool = false
var _result_auto_advance_time_left: float = 0.0
var _auto_resolve_queued: bool = false
var _result_reveal_played: bool = false
var _voting_reveal_played: bool = false

const RESULT_TRANSITION_SECONDS: float = 5.0

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
	_nominee_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_nominee_label.custom_minimum_size = Vector2(520, 0)
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
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instruction_label.custom_minimum_size = Vector2(560, 0)
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

	_result_countdown_label = _make_label("", 18, COLOR_DIM, HORIZONTAL_ALIGNMENT_CENTER)
	_result_countdown_label.visible = false
	_bottom_content.add_child(_result_countdown_label)

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
	if state.game_phase == "election" and state.auto_election_award_active and _is_election_resolved(state) and not _showing_result:
		_show_auto_election_result(state)
	if state.game_phase == "election" and not state.auto_election_award_active and _is_election_resolved(state) and not _showing_result:
		_enter_election_result_overlay()
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
		_nominee_label.text = _format_nomination_phase_message(state)
		_middle_content.visible = false
		_bottom_content.visible = false
		_voting_reveal_played = false
		_continue_button.visible = false
		if _result_countdown_label:
			_result_countdown_label.visible = false
		if _last_nominee_index != -1:
			_last_nominee_index = -1
			_last_nominee_button_key = ""
		if game_manager.is_online_game():
			_clear_hotseat_device_row()
		else:
			if state.players[state.current_consul_index].is_ai:
				_clear_hotseat_device_row()
				if not _hotseat_ai_nominate_attempted:
					_hotseat_ai_nominate_attempted = true
					game_manager.auto_select_ai_nominee()
			else:
				_sync_hotseat_device_row(state)
		_sync_nominee_choice_buttons(state)
	else:
		_clear_hotseat_device_row()
		var nominee = state.players[state.election_nominee_index]
		_nominee_label.text = "Nominated for co-consul: %s" % _player_name(nominee.player_id)
		if _last_nominee_index < 0:
			_clear_nominee_buttons()
			_last_nominee_index = state.election_nominee_index
		_last_nominee_button_key = ""

func _rebuild_nominee_buttons(state) -> void:
	_sync_nominee_choice_buttons(state)

func _may_show_nominee_buttons(state) -> bool:
	if state.election_nominee_index >= 0:
		return false
	if state.players[state.current_consul_index].is_ai:
		return false
	var eff: int = _effective_device_seat()
	if eff < 0 or eff >= state.players.size():
		return false
	if state.players[eff].is_dead:
		return false
	return eff == state.current_consul_index

func _effective_device_seat() -> int:
	if game_manager.is_online_game():
		return game_manager.get_local_seat()
	if game_manager:
		return game_manager.hotseat_viewer_seat
	return -1

func _format_nomination_phase_message(state) -> String:
	var consul_name: String = _player_name(state.current_consul_index)
	var candidates: Array = game_manager.get_nominee_candidates()
	var name_parts: Array = []
	for idx in candidates:
		name_parts.append(_player_name(idx))
	var pool: String = ", ".join(name_parts) if name_parts.size() > 0 else "— none eligible —"

	if state.players[state.current_consul_index].is_ai:
		return "The consul %s weighs the Senate.\nThose who may stand as co-consul: %s." % [consul_name, pool]

	var is_online: bool = game_manager.is_online_game()
	var holder: int = game_manager.get_local_seat() if is_online else (game_manager.hotseat_viewer_seat if game_manager else -1)

	if is_online:
		if holder < 0:
			return "Consul: %s.\nEligible representatives: %s." % [consul_name, pool]
		if holder == state.current_consul_index:
			return "Consul %s — the floor is yours.\nName a co-consul from: %s." % [consul_name, pool]
		return "Consul: %s.\nEligible: %s.\nThe Curia waits — only the consul nominates; you will vote when the ballot opens." % [consul_name, pool]

	if holder < 0:
		return "Consul: %s.\nEligible co-consuls: %s.\nWho holds the device? Touch your name below, then pass it to the consul." % [consul_name, pool]
	if holder == state.current_consul_index:
		return "Consul %s — the ivory seat speaks through you.\nEligible: %s.\nChoose a co-consul below." % [consul_name, pool]
	return "Consul: %s.\nEligible: %s.\nYou are seated as %s — hand the device to Consul %s so they may nominate." % [consul_name, pool, _player_name(holder), consul_name]

func _sync_hotseat_device_row(state) -> void:
	if game_manager.is_online_game() or state.election_nominee_index >= 0:
		return
	if state.players[state.current_consul_index].is_ai:
		return
	var key_parts: Array = []
	for i in range(state.players.size()):
		if not state.players[i].is_dead:
			key_parts.append(str(i))
	var row_key: String = "|".join(key_parts) + "@" + str(game_manager.hotseat_viewer_seat if game_manager else -1)
	if row_key == _last_device_row_key and _nominee_btn_container.get_node_or_null("HotseatDeviceHolderRow"):
		return
	_last_device_row_key = row_key
	_clear_hotseat_device_row()

	var row = HBoxContainer.new()
	row.name = "HotseatDeviceHolderRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)

	var hint = Label.new()
	hint.text = "Who holds the device?"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", COLOR_DIM)
	row.add_child(hint)

	for i in range(state.players.size()):
		if state.players[i].is_dead:
			continue
		var b = Button.new()
		b.text = _player_name(i)
		if i == (game_manager.hotseat_viewer_seat if game_manager else -1):
			b.modulate = Color(1.1, 1.05, 0.85, 1)
		b.pressed.connect(_on_hotseat_device_seat_pressed.bind(i))
		row.add_child(b)

	_nominee_btn_container.add_child(row)

func _on_hotseat_device_seat_pressed(seat: int) -> void:
	if game_manager:
		game_manager.hotseat_viewer_seat = seat
	_last_device_row_key = ""
	_last_nominee_button_key = ""

func _clear_hotseat_device_row() -> void:
	var row = _nominee_btn_container.get_node_or_null("HotseatDeviceHolderRow")
	if row:
		row.queue_free()
	_last_device_row_key = ""

func _sync_nominee_choice_buttons(state) -> void:
	if state.election_nominee_index >= 0:
		return
	var candidates: Array = game_manager.get_nominee_candidates()
	var cand_parts: Array = []
	for idx in candidates:
		cand_parts.append(str(idx))
	var cand_sig: String = ",".join(cand_parts)
	var key: String = "%s|%s|%s|%s" % [
		str(state.current_consul_index),
		str(_effective_device_seat()),
		str(_may_show_nominee_buttons(state)),
		cand_sig,
	]
	if key == _last_nominee_button_key:
		return
	_last_nominee_button_key = key
	_clear_nominee_buttons()
	if not _may_show_nominee_buttons(state):
		return
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

	if game_manager.is_online_game():
		_instruction_label.text = "Cast your vote, senator — Yea or Nay before the Curia."
	else:
		_instruction_label.text = "Citizens of Rome, cast your votes!"

	var all_humans_voted = game_manager.are_human_player_election_votes_complete()
	var all_voted = game_manager.are_election_votes_complete()
	var election_resolved = state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0

	var voter_indices: Array = []
	if game_manager.is_online_game():
		var local_seat: int = game_manager.get_local_seat()
		if local_seat >= 0 and local_seat < state.players.size():
			if state.players[local_seat].is_dead:
				var dead_note = Label.new()
				dead_note.text = "You hold no ballot — Rome does not call the dead to vote."
				dead_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				dead_note.add_theme_font_size_override("font_size", 18)
				dead_note.add_theme_color_override("font_color", COLOR_DIM)
				dead_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				dead_note.custom_minimum_size = Vector2(400, 0)
				_voter_grid.add_child(dead_note)
				_sync_election_result_chrome()
				return
			voter_indices.append(local_seat)
		else:
			var wait_label = Label.new()
			wait_label.text = "Waiting for seat assignment…"
			wait_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			wait_label.add_theme_font_size_override("font_size", 18)
			wait_label.add_theme_color_override("font_color", COLOR_DIM)
			_voter_grid.add_child(wait_label)
			_sync_election_result_chrome()
			return
	else:
		for player_id in range(state.players.size()):
			voter_indices.append(player_id)

	var player_count = max(1, voter_indices.size())
	var row_gap = 10
	var panel_inner_width = int(size.x) if size.x > 0 else 600
	var usable_width = panel_inner_width - 64
	var card_width = int(floor(float(usable_width - row_gap * (player_count - 1)) / float(player_count)))
	card_width = clamp(card_width, 80, 200)
	_voter_grid.add_theme_constant_override("separation", row_gap)

	for player_id in voter_indices:
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
		if game_manager.is_online_game() and state.election_nominee_index >= 0:
			var nominee_title: String = _player_name(state.election_nominee_index)
			name_label.text = "Shall %s stand as co-consul beside the consul?" % nominee_title
			name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			name_label.custom_minimum_size = Vector2(max(120, card_width - 16), 0)
		else:
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

	_sync_election_result_chrome()
	var ready_to_tally: bool = all_humans_voted if game_manager.is_online_game() else all_voted
	if ready_to_tally and not election_resolved and not _auto_resolve_queued and not _showing_result:
		if game_manager.is_online_game():
			var nm = get_node_or_null("/root/NetworkManager")
			if nm and nm.is_host():
				_auto_resolve_queued = true
				call_deferred("_resolve_election_and_show_result")
		else:
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
	if state.auto_election_award_active:
		return "Plebeian influence reached 6. %s names %s co-consul, and the senate yields without a vote." % [consul_name, nominee_name]
	if state.election_passed:
		var co_consul_name = _player_name(state.current_co_consul_index) if state.current_co_consul_index >= 0 else nominee_name
		return "%s and %s step into power as consul and co-consul." % [consul_name, co_consul_name]
	return "%s and %s do not gain power. The senate rejects their rise this round." % [consul_name, nominee_name]

func _is_election_resolved(state) -> bool:
	return state.election_votes_yes.size() > 0 or state.election_votes_no.size() > 0

func _enter_election_result_overlay() -> void:
	if _showing_result:
		return
	if not game_manager or not game_manager.state:
		return
	var st = game_manager.state
	_showing_result = true
	_result_auto_advance_time_left = RESULT_TRANSITION_SECONDS
	_sync_election_result_chrome()
	_update_continue_button_text()
	_last_vote_signature = ""
	_result_reveal_played = false
	_update_voting(st)
	_update_result(st)
	_play_result_reveal_animation()

func _show_auto_election_result(state) -> void:
	_showing_result = true
	_result_auto_advance_time_left = RESULT_TRANSITION_SECONDS
	_sync_election_result_chrome()
	_clear_nominee_buttons()
	_clear_hotseat_device_row()
	_last_nominee_index = state.election_nominee_index
	_middle_content.visible = false
	_bottom_content.visible = true
	_last_vote_signature = ""
	_update_continue_button_text()
	_update_result(state)
	_play_result_reveal_animation()

func reset_panel() -> void:
	_last_nominee_index = -99
	_last_vote_signature = ""
	_last_phase = ""
	_showing_result = false
	_result_auto_advance_time_left = 0.0
	_auto_resolve_queued = false
	_result_reveal_played = false
	_voting_reveal_played = false
	_hotseat_ai_nominate_attempted = false
	_last_nominee_button_key = ""
	_last_device_row_key = ""
	_middle_content.visible = false
	_middle_content.modulate = Color(1, 1, 1, 1)
	_bottom_content.visible = false
	_bottom_content.modulate = Color(1, 1, 1, 1)
	_continue_button.visible = false
	if _result_countdown_label:
		_result_countdown_label.visible = false
		_result_countdown_label.text = ""
	_clear_nominee_buttons()
	_clear_hotseat_device_row()
	for child in _voter_grid.get_children():
		child.queue_free()

# --- callbacks ---

func _on_nominee_selected(nominee_index: int) -> void:
	if _showing_result:
		return
	if game_manager and game_manager.state and _is_election_resolved(game_manager.state):
		return
	var st = game_manager.state
	if st.election_nominee_index < 0 and not game_manager.is_online_game():
		if not _may_show_nominee_buttons(st):
			return
	if game_manager.is_online_game():
		game_manager.rpc_select_nominee.rpc_id(1, nominee_index)
	else:
		game_manager.select_election_nominee(nominee_index)

func _on_vote_toggled(is_on: bool, player_id: int, is_yes: bool) -> void:
	if is_on:
		if game_manager.is_online_game():
			game_manager.rpc_submit_my_election_vote.rpc_id(1, is_yes)
		else:
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
	if _result_countdown_label:
		_result_countdown_label.visible = false
		_result_countdown_label.text = ""
	if game_manager and game_manager.state:
		if game_manager.state.game_phase == "election" and _is_election_resolved(game_manager.state):
			if game_manager.is_online_game():
				game_manager.rpc_progress.rpc_id(1)
			else:
				game_manager.progress()
		elif game_manager.state.game_phase == "round_end":
			if game_manager.is_online_game():
				game_manager.rpc_progress.rpc_id(1)
			else:
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
	if game_manager.is_online_game():
		if not game_manager.are_human_player_election_votes_complete():
			return
		var nm = get_node_or_null("/root/NetworkManager")
		if nm == null or not nm.is_host():
			return
		game_manager.rpc_resolve_election_tally.rpc_id(1)
		return
	if not game_manager.are_election_votes_complete():
		return
	game_manager.progress()
	_enter_election_result_overlay()

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

func _sync_election_result_chrome() -> void:
	if _continue_button:
		_continue_button.visible = false
	if _result_countdown_label:
		_result_countdown_label.visible = _showing_result


func _update_continue_button_text() -> void:
	if not _result_countdown_label or not _showing_result:
		return
	_result_countdown_label.text = "Next phase in %d…" % int(ceil(_result_auto_advance_time_left))

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
