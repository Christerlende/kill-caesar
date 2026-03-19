extends PanelContainer

const Role = preload("res://scripts/data/role.gd").Role
const _DiagonalStamp = preload("res://scripts/ui/diagonal_stamp.gd")

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.8)
const COLOR_A = Color(0.22, 0.42, 0.85, 0.85)
const COLOR_B = Color(0.78, 0.2, 0.14, 0.85)

var game_manager = null

var _title_label: Label
var _subtitle_label: Label
var _options_row: HBoxContainer
var _controls_box: VBoxContainer

var _draft_player_id: int = -1
var _draft_option: String = "A"
var _draft_amount: int = 0
var _last_ui_key: String = ""
var _resolved_animated: bool = false

func _ready() -> void:
	clip_contents = true

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var root = VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	margin.add_child(root)

	_title_label = Label.new()
	_title_label.text = "ENACT A DECREE"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 30)
	_title_label.add_theme_color_override("font_color", COLOR_GOLD)
	root.add_child(_title_label)

	root.add_child(HSeparator.new())

	_subtitle_label = Label.new()
	_subtitle_label.text = ""
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", COLOR_CREAM)
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_subtitle_label)

	_options_row = HBoxContainer.new()
	_options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_options_row.add_theme_constant_override("separation", 18)
	root.add_child(_options_row)

	_controls_box = VBoxContainer.new()
	_controls_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_controls_box.add_theme_constant_override("separation", 10)
	root.add_child(_controls_box)

func _process(_delta: float) -> void:
	if not game_manager:
		return
	var state = game_manager.state
	if not state or state.game_phase != "spending":
		return

	var ui_key = "%s|%d|%s|%d|%d|%d" % [
		state.spending_stage,
		state.spending_input_player_index,
		_draft_option,
		_draft_amount,
		state.spending_option_a_total,
		state.spending_option_b_total,
	]
	if ui_key == _last_ui_key:
		return
	_last_ui_key = ui_key

	_rebuild_ui(state)

func reset_panel() -> void:
	_draft_player_id = -1
	_draft_option = "A"
	_draft_amount = 0
	_last_ui_key = ""
	_resolved_animated = false

func is_preview_active() -> bool:
	return _draft_player_id >= 0

func preview_player_id() -> int:
	return _draft_player_id

func preview_remaining_gold() -> int:
	if not game_manager or _draft_player_id < 0:
		return -1
	var state = game_manager.state
	if not state:
		return -1
	if _draft_player_id >= state.players.size():
		return -1
	return max(0, state.players[_draft_player_id].money - _draft_amount)

func _rebuild_ui(state) -> void:
	for child in _options_row.get_children():
		child.queue_free()
	for child in _controls_box.get_children():
		child.queue_free()

	if state.policy_enacted != null:
		if state.spending_stage == "resolved":
			_subtitle_label.text = "The people have spoken."
		else:
			_subtitle_label.text = "Policy #%d enacted. Choose where to spend gold." % state.policy_enacted.id
		var result_a = ""
		var result_b = ""
		if state.spending_stage == "resolved":
			result_a = "won" if state.spending_winner == "A" else "lost"
			result_b = "won" if state.spending_winner == "B" else "lost"
		var card_a = _build_option_card("A", state.policy_enacted.option_a_text, COLOR_A, state, result_a)
		var card_b = _build_option_card("B", state.policy_enacted.option_b_text, COLOR_B, state, result_b)
		if state.spending_stage == "resolved":
			var col_a = _wrap_card_with_tribute(card_a, "A", state)
			var col_b = _wrap_card_with_tribute(card_b, "B", state)
			_options_row.add_child(col_a)
			_options_row.add_child(col_b)
			if not _resolved_animated:
				_resolved_animated = true
				call_deferred("_animate_resolved", card_a, card_b, state.spending_winner)
		else:
			_options_row.add_child(card_a)
			_options_row.add_child(card_b)
	else:
		_subtitle_label.text = "Preparing treasury vote..."

	match state.spending_stage:
		"input":
			_build_input_controls(state)
		"handoff":
			_build_handoff_controls(state)
		"resolved":
			_build_resolved_controls(state)
		_:
			var waiting = Label.new()
			waiting.text = "Waiting for spending phase..."
			waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_controls_box.add_child(waiting)

func _build_option_card(letter: String, text: String, accent: Color, state, result: String = "") -> PanelContainer:
	var is_winner = result == "won"
	var is_loser = result == "lost"

	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(300, 250)
	card.clip_contents = true

	var bg_color = Color(0.16, 0.08, 0.06, 0.95)
	var border_color = accent
	var border_width = 2
	if is_loser:
		bg_color = Color(0.10, 0.10, 0.10, 0.95)
		border_color = Color(0.35, 0.35, 0.35, 0.7)
	elif is_winner:
		border_width = 3

	var style = StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", style)

	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var header = Label.new()
	header.text = "Decree %s" % _decree_number_from_option_key(letter)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20 if is_winner else 18)
	header.add_theme_color_override("font_color", border_color)
	box.add_child(header)

	var body = Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 1) if is_loser else COLOR_CREAM)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)

	if state.spending_stage == "input":
		var player_money = game_manager.get_current_spending_player_money()
		var is_active_option = _draft_option == letter
		var is_other_locked = _draft_amount > 0 and not is_active_option
		var shown_amount = _draft_amount if is_active_option else 0

		var control_row = HBoxContainer.new()
		control_row.alignment = BoxContainer.ALIGNMENT_CENTER
		control_row.add_theme_constant_override("separation", 10)

		var minus_btn = Button.new()
		minus_btn.text = "-"
		minus_btn.disabled = not is_active_option or _draft_amount <= 0
		minus_btn.pressed.connect(_on_option_minus_pressed.bind(letter))
		control_row.add_child(minus_btn)

		var amount_label = Label.new()
		amount_label.text = str(shown_amount) if shown_amount > 0 else ""
		amount_label.custom_minimum_size = Vector2(24, 0)
		amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amount_label.add_theme_color_override("font_color", COLOR_GOLD)
		control_row.add_child(amount_label)

		var plus_btn = Button.new()
		plus_btn.text = "+"
		plus_btn.disabled = is_other_locked or (is_active_option and _draft_amount >= player_money)
		plus_btn.pressed.connect(_on_option_plus_pressed.bind(letter, player_money))
		control_row.add_child(plus_btn)

		box.add_child(control_row)

	if result != "":
		var stamp = _DiagonalStamp.new()
		stamp.name = "Stamp"
		stamp.band_color = Color(0.10, 0.60, 0.15, 0.88) if is_winner else Color(0.68, 0.10, 0.08, 0.85)
		stamp.stamp_text = "ENACTED" if is_winner else "VETOED"
		stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stamp.modulate = Color(1, 1, 1, 0)
		card.add_child(stamp)

	return card

func _build_input_controls(state) -> void:
	var player_id = game_manager.get_current_spending_player_id()
	if _draft_player_id != player_id:
		_draft_player_id = player_id
		_draft_option = "A"
		_draft_amount = 0

	var title = Label.new()
	title.text = "Player %d: cast your treasury vote" % (player_id + 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD)
	title.add_theme_font_size_override("font_size", 20)
	_controls_box.add_child(title)

	var spend_label = Label.new()
	spend_label.text = "Spend gold: %d" % _draft_amount
	spend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	spend_label.add_theme_color_override("font_color", COLOR_CREAM)
	spend_label.add_theme_font_size_override("font_size", 18)
	_controls_box.add_child(spend_label)

	var pay_btn = Button.new()
	pay_btn.text = "Render Tribute"
	pay_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pay_btn.disabled = _draft_amount <= 0
	pay_btn.pressed.connect(_on_pay_pressed)
	_controls_box.add_child(pay_btn)

	var hint = Label.new()
	hint.text = "Unspent gold remains in your purse."
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", COLOR_DIM)
	_controls_box.add_child(hint)

func _build_handoff_controls(state) -> void:
	if game_manager and game_manager.advance_spending_turn():
		_last_ui_key = ""

func _build_resolved_controls(state) -> void:
	_draft_player_id = -1

	var proceed_btn = Button.new()
	proceed_btn.text = "Proceed"
	proceed_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	proceed_btn.pressed.connect(_on_resolved_proceed_pressed)
	_controls_box.add_child(proceed_btn)

func _on_option_minus_pressed(option_key: String) -> void:
	if _draft_option != option_key or _draft_amount <= 0:
		return
	_draft_amount -= 1
	if _draft_amount < 0:
		_draft_amount = 0
	_last_ui_key = ""

func _on_option_plus_pressed(option_key: String, max_money: int) -> void:
	if _draft_amount == 0:
		_draft_option = option_key
	if _draft_option != option_key:
		return
	_draft_amount = clamp(_draft_amount + 1, 0, max_money)
	_last_ui_key = ""

func _on_pay_pressed() -> void:
	game_manager.set_spending_allocation(_draft_option, _draft_amount)
	_last_ui_key = ""

func _on_pass_pressed() -> void:
	game_manager.advance_spending_turn()
	_last_ui_key = ""

func _on_resolved_proceed_pressed() -> void:
	game_manager.progress()
	if game_manager.state.game_phase == "round_end":
		game_manager.progress()
	_last_ui_key = ""

func _decree_number_from_option_key(option_key: String) -> String:
	if option_key == "A":
		return "1"
	if option_key == "B":
		return "2"
	return option_key

func _wrap_card_with_tribute(card: PanelContainer, letter: String, state) -> VBoxContainer:
	var is_winner = (letter == state.spending_winner)
	var gold_amount = state.spending_option_a_total if letter == "A" else state.spending_option_b_total

	var col = VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 18)
	col.add_child(card)

	var tribute_label = Label.new()
	tribute_label.name = "TributeLabel"
	tribute_label.text = "Tribute pledged: %d gold" % gold_amount
	tribute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tribute_label.add_theme_font_size_override("font_size", 19)
	tribute_label.add_theme_color_override("font_color", COLOR_GOLD if is_winner else COLOR_DIM)
	tribute_label.modulate = Color(1, 1, 1, 0)
	col.add_child(tribute_label)

	return col

func _animate_resolved(card_a: PanelContainer, card_b: PanelContainer, winner: String) -> void:
	var winner_card = card_a if winner == "A" else card_b
	var loser_card = card_b if winner == "A" else card_a

	# Pivot from center so scale looks natural
	winner_card.pivot_offset = Vector2(150, 125)
	loser_card.pivot_offset = Vector2(150, 125)

	var tween = create_tween()
	tween.set_parallel(true)

	# Winner grows with a slight overshoot
	winner_card.scale = Vector2.ONE
	tween.tween_property(winner_card, "scale", Vector2(1.14, 1.14), 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Loser shrinks subtly
	loser_card.scale = Vector2.ONE
	tween.tween_property(loser_card, "scale", Vector2(0.92, 0.92), 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Fade in diagonal stamps and tribute labels after a short delay
	for card in [winner_card, loser_card]:
		var stamp = card.get_node_or_null("Stamp")
		if stamp:
			tween.tween_property(stamp, "modulate:a", 1.0, 0.5).set_delay(0.4)
		# Tribute label is now in the wrapper VBoxContainer (card's parent)
		var wrapper = card.get_parent()
		if wrapper:
			var tribute = wrapper.get_node_or_null("TributeLabel")
			if tribute:
				tween.tween_property(tribute, "modulate:a", 1.0, 0.5).set_delay(0.3)