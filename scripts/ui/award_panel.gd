extends PanelContainer

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.75)
const COLOR_RED = Color(0.72, 0.14, 0.1, 0.9)

const REVEAL_SECONDS: float = 3.0
const AWARD_NONE: int = -1
const AWARD_PLEBEIAN_2_ROLE_PEEK: int = 0
const AWARD_PLEBEIAN_4_TWO_ROLE_PEEK: int = 1
const AWARD_PLEBEIAN_6_AUTO_ELECTION: int = 2
const AWARD_PATRICIAN_2_DOUBLE_DISCARD: int = 3
const AWARD_PATRICIAN_4_ROLE_PEEK: int = 4
const AWARD_PATRICIAN_6_EXECUTION: int = 5

var game_manager = null

var _root: VBoxContainer
var _title_label: Label
var _instruction_label: Label
var _content: VBoxContainer
var _continue_button: Button
var _last_award_id: int = AWARD_NONE
var _handoff_complete: bool = false
var _selected_player_ids: Array = []
var _reveal_timer_active: bool = false
var _execution_done: bool = false

func _ready() -> void:
	clip_contents = true

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	add_child(margin)

	_root = VBoxContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_theme_constant_override("separation", 18)
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_root)

	_title_label = _make_label("", 34, COLOR_GOLD)
	_root.add_child(_title_label)

	_instruction_label = _make_label("", 19, COLOR_CREAM)
	_instruction_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_root.add_child(_instruction_label)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 12)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(_content)

	_continue_button = Button.new()
	_continue_button.text = "Continue"
	_continue_button.visible = false
	_continue_button.pressed.connect(_on_continue_pressed)
	_continue_button.add_theme_color_override("font_color", COLOR_CREAM)
	_root.add_child(_continue_button)

func _process(_delta: float) -> void:
	if not game_manager or not game_manager.state:
		return
	var state = game_manager.state
	if state.game_phase != "award":
		return
	var award_id = state.current_award_id
	if award_id != _last_award_id:
		_start_award(award_id)

func reset_panel() -> void:
	_last_award_id = AWARD_NONE
	_handoff_complete = false
	_selected_player_ids.clear()
	_reveal_timer_active = false
	_execution_done = false
	_continue_button.visible = false
	_title_label.text = ""
	_instruction_label.text = ""
	_instruction_label.add_theme_color_override("font_color", COLOR_CREAM)
	_clear_content()

func _start_award(award_id: int) -> void:
	_last_award_id = award_id
	_handoff_complete = award_id == AWARD_PATRICIAN_6_EXECUTION
	_selected_player_ids.clear()
	_reveal_timer_active = false
	_execution_done = false
	_continue_button.visible = false
	_instruction_label.add_theme_color_override("font_color", COLOR_CREAM)
	_clear_content()
	_title_label.text = _award_title(award_id)
	if _handoff_complete:
		_show_award_controls()
	else:
		_show_handoff()

func _show_handoff() -> void:
	var consul_name = game_manager.get_player_name(game_manager.state.current_consul_index)
	_instruction_label.text = "Pass the device to Consul %s. Only the consul should see the reveal." % consul_name
	var ready_button = Button.new()
	ready_button.text = "Consul is ready"
	ready_button.pressed.connect(_on_handoff_ready)
	_content.add_child(ready_button)

func _on_handoff_ready() -> void:
	_handoff_complete = true
	_show_award_controls()

func _show_award_controls() -> void:
	_clear_content()
	_continue_button.visible = false
	var award_id = game_manager.get_current_award_id()
	match award_id:
		AWARD_PLEBEIAN_2_ROLE_PEEK, AWARD_PATRICIAN_4_ROLE_PEEK:
			_instruction_label.text = "Choose one player. Their secret role will be shown for %d seconds." % int(REVEAL_SECONDS)
			_build_player_buttons("Reveal role", _on_single_peek_selected)
		AWARD_PLEBEIAN_4_TWO_ROLE_PEEK:
			_instruction_label.text = "Choose two players. You will see only the two roles, not which role belongs to which player."
			_build_two_role_picker()
		AWARD_PATRICIAN_6_EXECUTION:
			_instruction_label.text = "The consul must kill one player. The consul cannot kill himself."
			_build_player_buttons("Kill", _on_execution_target_selected)
		_:
			_instruction_label.text = "No award to resolve."
			_continue_button.visible = true

func _build_player_buttons(button_text: String, callback: Callable) -> void:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	for player_id in _eligible_target_ids():
		var b = Button.new()
		b.text = "%s: %s" % [button_text, game_manager.get_player_name(player_id)]
		b.pressed.connect(callback.bind(player_id))
		row.add_child(b)

func _build_two_role_picker() -> void:
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	_content.add_child(row)
	for player_id in _eligible_target_ids():
		var cb = CheckBox.new()
		cb.text = game_manager.get_player_name(player_id)
		cb.button_pressed = _selected_player_ids.has(player_id)
		cb.toggled.connect(_on_two_role_target_toggled.bind(player_id))
		row.add_child(cb)

	var reveal_button = Button.new()
	reveal_button.text = "Reveal two roles"
	reveal_button.disabled = _selected_player_ids.size() != 2
	reveal_button.pressed.connect(_on_two_role_reveal_pressed)
	_content.add_child(reveal_button)

func _eligible_target_ids() -> Array:
	var out = []
	if not game_manager or not game_manager.state:
		return out
	for i in range(game_manager.state.players.size()):
		var player = game_manager.state.players[i]
		if player.is_dead:
			continue
		if i == game_manager.state.current_consul_index:
			continue
		out.append(i)
	return out

func _on_single_peek_selected(player_id: int) -> void:
	if _reveal_timer_active:
		return
	var role = game_manager.award_peek_role(player_id)
	if role < 0:
		return
	_show_timed_reveal("Secret role: %s" % game_manager.role_name(role))

func _on_two_role_target_toggled(is_on: bool, player_id: int) -> void:
	if is_on:
		if not _selected_player_ids.has(player_id) and _selected_player_ids.size() < 2:
			_selected_player_ids.append(player_id)
	else:
		_selected_player_ids.erase(player_id)
	_show_award_controls()

func _on_two_role_reveal_pressed() -> void:
	if _selected_player_ids.size() != 2 or _reveal_timer_active:
		return
	var roles = game_manager.award_peek_two_roles(_selected_player_ids[0], _selected_player_ids[1])
	if roles.size() != 2:
		return
	_show_timed_reveal(_format_two_role_reveal(roles))

func _on_execution_target_selected(player_id: int) -> void:
	if _execution_done:
		return
	_clear_content()
	_instruction_label.text = "Kill %s?" % game_manager.get_player_name(player_id)
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	_content.add_child(row)
	var confirm = Button.new()
	confirm.text = "Confirm kill"
	confirm.pressed.connect(_confirm_execution.bind(player_id))
	row.add_child(confirm)
	var cancel = Button.new()
	cancel.text = "Cancel"
	cancel.pressed.connect(_show_award_controls)
	row.add_child(cancel)

func _confirm_execution(player_id: int) -> void:
	if not game_manager.award_execute_player(player_id):
		_show_award_controls()
		return
	_execution_done = true
	_clear_content()
	_instruction_label.text = "%s has been killed." % game_manager.get_player_name(player_id)
	_continue_button.visible = true

func _show_timed_reveal(text: String) -> void:
	_reveal_timer_active = true
	_clear_content()
	_instruction_label.text = text
	_instruction_label.add_theme_color_override("font_color", COLOR_GOLD)
	get_tree().create_timer(REVEAL_SECONDS).timeout.connect(_hide_reveal)

func _hide_reveal() -> void:
	if not _reveal_timer_active:
		return
	_reveal_timer_active = false
	_clear_content()
	_instruction_label.add_theme_color_override("font_color", COLOR_CREAM)
	_instruction_label.text = "The reveal is over. The consul must remember what was shown."
	_continue_button.visible = true

func _format_two_role_reveal(roles: Array) -> String:
	if roles[0] == roles[1]:
		return "Two %s representatives" % game_manager.role_name(roles[0]).to_lower()
	return "%s and %s" % [_role_phrase(roles[0]), _role_phrase(roles[1])]

func _role_phrase(role: int) -> String:
	if role == game_manager.Role.CAESAR:
		return "Caesar"
	return "One %s representative" % game_manager.role_name(role).to_lower()

func _award_title(award_id: int) -> String:
	match award_id:
		AWARD_PLEBEIAN_2_ROLE_PEEK:
			return "PLEBEIAN INFLUENCE: ROLE PEEK"
		AWARD_PLEBEIAN_4_TWO_ROLE_PEEK:
			return "PLEBEIAN INFLUENCE: TWO ROLE PEEK"
		AWARD_PLEBEIAN_6_AUTO_ELECTION:
			return "PLEBEIAN INFLUENCE: AUTO ELECTION"
		AWARD_PATRICIAN_2_DOUBLE_DISCARD:
			return "PATRICIAN INFLUENCE: DOUBLE DISCARD"
		AWARD_PATRICIAN_4_ROLE_PEEK:
			return "PATRICIAN INFLUENCE: ROLE PEEK"
		AWARD_PATRICIAN_6_EXECUTION:
			return "PATRICIAN INFLUENCE: EXECUTION"
		_:
			return "INFLUENCE AWARD"

func _on_continue_pressed() -> void:
	if game_manager:
		game_manager.finish_current_award()
		if game_manager.state.game_phase == "round_end":
			game_manager.progress()
	reset_panel()

func _clear_content() -> void:
	for child in _content.get_children():
		child.queue_free()

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l
