extends PanelContainer

const Role = preload("res://scripts/data/role.gd").Role

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)
const COLOR_DARK_BG = Color(0.08, 0.04, 0.03, 0.85)
const COLOR_SCROLL_BG = Color(0.18, 0.12, 0.07, 0.95)
const COLOR_SCROLL_BORDER = Color(0.6, 0.48, 0.2, 0.7)

var game_manager = null
var _viewer_index: int = 0

var _role_title_label: Label
var _purse_amount_label: Label
var _income_label: Label
var _intel_section: VBoxContainer
var _rules_popup: PanelContainer
var _howtowin_popup: PanelContainer

var _last_ui_key: String = ""

func _ready() -> void:
	clip_contents = true

	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root = VBoxContainer.new()
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)

	# --- Secret Role Title ---
	_role_title_label = Label.new()
	_role_title_label.text = "Secret role: —"
	_role_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_title_label.add_theme_font_size_override("font_size", 18)
	_role_title_label.add_theme_color_override("font_color", COLOR_GOLD)
	_role_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_role_title_label)

	root.add_child(HSeparator.new())

	# --- Purse Section ---
	var purse_box = _build_purse_section()
	root.add_child(purse_box)

	root.add_child(HSeparator.new())

	# --- Role Intel Section ---
	_intel_section = VBoxContainer.new()
	_intel_section.add_theme_constant_override("separation", 6)
	root.add_child(_intel_section)

	# --- Spacer to push scroll buttons to bottom ---
	var spacer = Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(spacer)

	# --- Scroll Buttons ---
	var scroll_row = HBoxContainer.new()
	scroll_row.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll_row.add_theme_constant_override("separation", 10)
	root.add_child(scroll_row)

	var rules_btn = _build_scroll_button("Rules")
	rules_btn.mouse_entered.connect(_on_rules_hover_enter)
	rules_btn.mouse_exited.connect(_on_rules_hover_exit)
	scroll_row.add_child(rules_btn)

	var howtowin_btn = _build_scroll_button("How to Win")
	howtowin_btn.mouse_entered.connect(_on_howtowin_hover_enter)
	howtowin_btn.mouse_exited.connect(_on_howtowin_hover_exit)
	scroll_row.add_child(howtowin_btn)

	# --- Hover Popups (initially hidden) ---
	_rules_popup = _build_hover_popup("Rules")
	add_child(_rules_popup)

	_howtowin_popup = _build_hover_popup("How to Win")
	add_child(_howtowin_popup)

func _build_purse_section() -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_DARK_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_SCROLL_BORDER
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	card.add_theme_stylebox_override("panel", style)

	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)

	var purse_header = Label.new()
	purse_header.text = "Purse"
	purse_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	purse_header.add_theme_font_size_override("font_size", 16)
	purse_header.add_theme_color_override("font_color", COLOR_CREAM)
	col.add_child(purse_header)

	var gold_row = HBoxContainer.new()
	gold_row.alignment = BoxContainer.ALIGNMENT_CENTER
	gold_row.add_theme_constant_override("separation", 8)
	col.add_child(gold_row)

	_purse_amount_label = Label.new()
	_purse_amount_label.text = "0"
	_purse_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_purse_amount_label.add_theme_font_size_override("font_size", 28)
	_purse_amount_label.add_theme_color_override("font_color", COLOR_GOLD)
	gold_row.add_child(_purse_amount_label)

	_income_label = Label.new()
	_income_label.text = "+0/round"
	_income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_income_label.add_theme_font_size_override("font_size", 14)
	_income_label.add_theme_color_override("font_color", Color(0.80, 0.68, 0.20, 0.8))
	gold_row.add_child(_income_label)

	return card

func _build_scroll_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(90, 36)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_SCROLL_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = COLOR_SCROLL_BORDER
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	btn.add_theme_stylebox_override("normal", style)

	var hover_style = style.duplicate()
	hover_style.bg_color = Color(0.24, 0.16, 0.08, 0.95)
	hover_style.border_color = COLOR_GOLD
	btn.add_theme_stylebox_override("hover", hover_style)
	btn.add_theme_stylebox_override("focus", style)
	btn.add_theme_stylebox_override("pressed", hover_style)

	btn.add_theme_color_override("font_color", COLOR_CREAM)
	btn.add_theme_color_override("font_hover_color", COLOR_GOLD)
	btn.add_theme_font_size_override("font_size", 13)
	return btn

func _build_hover_popup(title: String) -> PanelContainer:
	var popup = PanelContainer.new()
	popup.visible = false
	popup.top_level = true
	popup.z_index = 10
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.custom_minimum_size = Vector2(180, 120)
	popup.clip_contents = true

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.06, 0.04, 0.96)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_GOLD
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	popup.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.add_child(vbox)

	var header = Label.new()
	header.text = title
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_font_size_override("font_size", 20)
	header.add_theme_color_override("font_color", COLOR_GOLD)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	var sep = HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(sep)

	var body = Label.new()
	body.text = "(Coming soon)"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_size_override("font_size", 14)
	body.add_theme_color_override("font_color", COLOR_DIM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(body)

	return popup

func _process(_delta: float) -> void:
	if not game_manager:
		return
	var state = game_manager.state
	if not state or state.players.size() == 0:
		return

	_viewer_index = _get_viewer_index(state)
	var player = state.players[_viewer_index]
	var ui_key = "%d|%d|%d" % [_viewer_index, player.money, player.role]
	if ui_key == _last_ui_key:
		return
	_last_ui_key = ui_key

	_update_role_title(player)
	_update_purse(player)
	_update_intel(state, player)

func _get_viewer_index(state) -> int:
	if state.game_phase == "spending" and state.spending_stage == "input":
		return clamp(state.spending_input_player_index, 0, state.players.size() - 1)
	return clamp(state.current_consul_index, 0, state.players.size() - 1)

func _role_display_name(role: int) -> String:
	match role:
		Role.CAESAR:
			return "Caesar"
		Role.PATRICIAN:
			return "Patrician Representative"
		Role.PLEBIAN:
			return "Plebeian Representative"
		_:
			return "Unknown"

func _intel_role_name(role: int) -> String:
	match role:
		Role.CAESAR:
			return "Caesar"
		Role.PATRICIAN:
			return "Patrician"
		Role.PLEBIAN:
			return "Plebeian"
		_:
			return "Unknown"

func _role_color(role: int) -> Color:
	match role:
		Role.CAESAR:
			return COLOR_GOLD
		Role.PATRICIAN:
			return Color(0.76, 0.16, 0.12, 1.0)
		Role.PLEBIAN:
			return Color(0.35, 0.55, 1.0, 1.0)
		_:
			return COLOR_CREAM

func _gold_gain_for_role(role: int) -> int:
	match role:
		Role.CAESAR:
			return 8
		Role.PATRICIAN:
			return 6
		_:
			return 4

func _update_role_title(player) -> void:
	_role_title_label.text = "Secret role:\n%s" % _role_display_name(player.role)

func _update_purse(player) -> void:
	_purse_amount_label.text = str(player.money)
	_income_label.text = "+%d/round" % _gold_gain_for_role(player.role)

func _update_intel(state, player) -> void:
	for child in _intel_section.get_children():
		child.queue_free()

	match player.role:
		Role.CAESAR:
			var header = Label.new()
			header.text = "Intelligence"
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.add_theme_font_size_override("font_size", 16)
			header.add_theme_color_override("font_color", COLOR_GOLD)
			_intel_section.add_child(header)

			for p in state.players:
				if p.player_id == player.player_id:
					continue
				var line = Label.new()
				line.text = "P%d — %s" % [p.player_id + 1, _intel_role_name(p.role)]
				line.add_theme_font_size_override("font_size", 13)
				line.add_theme_color_override("font_color", _role_color(p.role))
				_intel_section.add_child(line)

		Role.PATRICIAN:
			var header = Label.new()
			header.text = "Intelligence"
			header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			header.add_theme_font_size_override("font_size", 16)
			header.add_theme_color_override("font_color", COLOR_GOLD)
			_intel_section.add_child(header)

			for p in state.players:
				if p.player_id == player.player_id:
					continue
				if p.role == Role.PATRICIAN:
					var line = Label.new()
					line.text = "Your ally: Player %d" % (p.player_id + 1)
					line.add_theme_font_size_override("font_size", 14)
					line.add_theme_color_override("font_color", COLOR_CREAM)
					_intel_section.add_child(line)
					break

		Role.PLEBIAN:
			var hint = Label.new()
			hint.text = "Trust no one."
			hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			hint.add_theme_font_size_override("font_size", 14)
			hint.add_theme_color_override("font_color", COLOR_DIM)
			_intel_section.add_child(hint)

# --- Hover Popup Callbacks ---

func _on_rules_hover_enter() -> void:
	_rules_popup.visible = true
	var popup_w = _rules_popup.custom_minimum_size.x
	var center_x = global_position.x + (size.x - popup_w) / 2.0
	_rules_popup.global_position = Vector2(center_x, global_position.y + 10)

func _on_rules_hover_exit() -> void:
	_rules_popup.visible = false

func _on_howtowin_hover_enter() -> void:
	_howtowin_popup.visible = true
	var popup_w = _howtowin_popup.custom_minimum_size.x
	var center_x = global_position.x + (size.x - popup_w) / 2.0
	_howtowin_popup.global_position = Vector2(center_x, global_position.y + 10)

func _on_howtowin_hover_exit() -> void:
	_howtowin_popup.visible = false
