extends PanelContainer

# Roman-themed policy discard panel.
# Shows 3 scroll-style policy cards. Consul discards one, then co-consul discards one.

const Role = preload("res://scripts/data/role.gd").Role

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_RED_FACTION = Color(0.72, 0.14, 0.1, 0.85)
const COLOR_BLUE_FACTION = Color(0.15, 0.3, 0.7, 0.85)
const COLOR_PARCHMENT = Color(0.85, 0.75, 0.58, 1)
const COLOR_PARCHMENT_EDGE = Color(0.62, 0.52, 0.36, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)
const COLOR_GREYED = Color(0.25, 0.22, 0.18, 0.8)
const COLOR_GREYED_BORDER = Color(0.35, 0.3, 0.22, 0.5)
const COLOR_PILL_BG = Color(0.0, 0.0, 0.0, 0.15)
const COLOR_DARK_BG = Color(0.08, 0.04, 0.03, 0.85)

var game_manager = null

# layout refs
var _header_label: Label
var _stage_label: Label
var _cards_row: HBoxContainer
var _confirm_section: VBoxContainer
var _confirm_label: Label
var _confirm_button: Button
var _cancel_button: Button

# state
var _selected_policy_id: int = -1
var _last_ui_key: String = ""
var _card_nodes: Dictionary = {}  # policy_id -> PanelContainer

func _ready():
	var margin = MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(margin)

	var root_vbox = VBoxContainer.new()
	root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_theme_constant_override("separation", 14)
	margin.add_child(root_vbox)

	# Header
	_header_label = _make_label("POLICY DECREE", 30, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	root_vbox.add_child(_header_label)
	root_vbox.add_child(HSeparator.new())

	# Stage prompt
	_stage_label = _make_label("", 18, COLOR_CREAM, HORIZONTAL_ALIGNMENT_CENTER)
	root_vbox.add_child(_stage_label)

	# Cards row
	_cards_row = HBoxContainer.new()
	_cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_cards_row.add_theme_constant_override("separation", 24)
	root_vbox.add_child(_cards_row)

	# Confirmation section
	_confirm_section = VBoxContainer.new()
	_confirm_section.add_theme_constant_override("separation", 8)
	_confirm_section.visible = false
	root_vbox.add_child(_confirm_section)

	_confirm_label = _make_label("", 18, COLOR_GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_confirm_section.add_child(_confirm_label)

	var btn_row = HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 16)
	_confirm_section.add_child(btn_row)

	_confirm_button = Button.new()
	_confirm_button.text = "Confirm Discard"
	_confirm_button.pressed.connect(_on_confirm_pressed)
	btn_row.add_child(_confirm_button)

	_cancel_button = Button.new()
	_cancel_button.text = "Cancel"
	_cancel_button.pressed.connect(_on_cancel_pressed)
	btn_row.add_child(_cancel_button)

func _process(_delta):
	if not game_manager:
		return
	var state = game_manager.state
	if not state or state.game_phase != "policy":
		return
	if state.policy_enacted != null:
		return

	var stage = game_manager.get_policy_discard_stage()
	var candidates = game_manager.get_policy_discard_candidates()
	var ui_key = "%s|%s|%d|%d" % [stage, _int_list(candidates), state.policy_discarded_ids.size(), _selected_policy_id]
	if ui_key == _last_ui_key:
		return
	_last_ui_key = ui_key

	_update_stage_label(state, stage)
	_rebuild_cards(state, stage, candidates)

func _update_stage_label(state, stage: String) -> void:
	if stage == "consul":
		var consul = state.players[state.current_consul_index]
		_stage_label.text = "Consul (Player %d) — choose a policy to discard" % consul.player_id
	elif stage == "co_consul":
		var co = state.players[state.current_co_consul_index]
		_stage_label.text = "Co-Consul (Player %d) — choose a policy to discard" % co.player_id
	else:
		_stage_label.text = ""

func _rebuild_cards(state, stage: String, active_ids: Array) -> void:
	for child in _cards_row.get_children():
		child.queue_free()
	_card_nodes.clear()

	# All drawn policy IDs (always show 3 slots)
	var all_drawn_ids = state.policy_drawn_ids
	var discarded_ids = state.policy_discarded_ids

	for policy_id in all_drawn_ids:
		var is_discarded = discarded_ids.has(policy_id)
		var is_active = active_ids.has(policy_id)
		var is_selected = (policy_id == _selected_policy_id)

		# Find the policy object if available
		var policy = null
		for p in game_manager.pending_policy_choices:
			if p.id == policy_id:
				policy = p
				break

		var card: PanelContainer
		if is_discarded and stage == "co_consul":
			# Co-consul sees discarded card as blank — no info
			card = _build_blank_card()
		elif is_discarded:
			# Consul stage: shouldn't happen (only 1 discard at consul stage)
			card = _build_blank_card()
		elif is_selected:
			card = _build_policy_card(policy, true, true)
		elif is_active:
			card = _build_policy_card(policy, false, true)
		else:
			card = _build_blank_card()

		_cards_row.add_child(card)
		_card_nodes[policy_id] = card

	# Confirmation
	if _selected_policy_id >= 0:
		_confirm_section.visible = true
		_confirm_label.text = "Discard Policy #%d?" % _selected_policy_id
	else:
		_confirm_section.visible = false

func _build_policy_card(policy, is_greyed: bool, is_clickable: bool) -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 280)

	# Scroll/parchment style
	var card_style = StyleBoxFlat.new()
	if is_greyed:
		card_style.bg_color = COLOR_GREYED
		card_style.border_color = COLOR_GREYED_BORDER
	else:
		card_style.bg_color = COLOR_PARCHMENT
		card_style.border_color = COLOR_PARCHMENT_EDGE
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card_style.content_margin_left = 12.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_top = 10.0
	card_style.content_margin_bottom = 10.0
	# Scroll roll shadow effect via expanded margins
	card_style.shadow_color = Color(0.15, 0.1, 0.05, 0.4)
	card_style.shadow_size = 6
	card.add_theme_stylebox_override("panel", card_style)

	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	card.add_child(col)

	if policy == null:
		var empty = _make_label("???", 20, COLOR_DIM, HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(empty)
		return card

	# Faction banner
	var faction_banner = PanelContainer.new()
	var banner_style = StyleBoxFlat.new()
	banner_style.bg_color = COLOR_RED_FACTION if policy.faction == Role.PATRICIAN else COLOR_BLUE_FACTION
	banner_style.corner_radius_top_left = 4
	banner_style.corner_radius_top_right = 4
	banner_style.corner_radius_bottom_left = 4
	banner_style.corner_radius_bottom_right = 4
	banner_style.content_margin_left = 8.0
	banner_style.content_margin_right = 8.0
	banner_style.content_margin_top = 4.0
	banner_style.content_margin_bottom = 4.0
	faction_banner.add_theme_stylebox_override("panel", banner_style)
	var faction_text = "PATRICIAN" if policy.faction == Role.PATRICIAN else "PLEBEIAN"
	var faction_color = COLOR_CREAM if not is_greyed else Color(0.5, 0.48, 0.42, 0.7)
	var faction_label = _make_label(faction_text, 16, faction_color, HORIZONTAL_ALIGNMENT_CENTER)
	faction_banner.add_child(faction_label)
	col.add_child(faction_banner)

	# Policy ID
	var id_color = Color(0.3, 0.25, 0.15, 1) if not is_greyed else Color(0.5, 0.48, 0.42, 0.7)
	var id_label = _make_label("Policy #%d" % policy.id, 14, id_color, HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(id_label)

	col.add_child(HSeparator.new())

	# Option A pill
	var text_color = Color(0.2, 0.15, 0.08, 1) if not is_greyed else Color(0.45, 0.4, 0.35, 0.6)
	col.add_child(_build_option_pill("A", policy.option_a_text, text_color, is_greyed))

	# Option B pill
	col.add_child(_build_option_pill("B", policy.option_b_text, text_color, is_greyed))

	# Click area (invisible button overlay)
	if is_clickable and not is_greyed:
		var click_btn = Button.new()
		click_btn.text = "Select"
		click_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		click_btn.pressed.connect(_on_card_clicked.bind(policy.id))
		col.add_child(click_btn)
	elif is_greyed and is_clickable:
		var selected_label = _make_label("SELECTED", 14, Color(0.9, 0.3, 0.2, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
		col.add_child(selected_label)

	return card

func _build_blank_card() -> PanelContainer:
	var card = PanelContainer.new()
	card.custom_minimum_size = Vector2(220, 280)
	var card_style = StyleBoxFlat.new()
	card_style.bg_color = COLOR_GREYED
	card_style.border_color = COLOR_GREYED_BORDER
	card_style.border_width_left = 3
	card_style.border_width_top = 3
	card_style.border_width_right = 3
	card_style.border_width_bottom = 3
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card_style.content_margin_left = 12.0
	card_style.content_margin_right = 12.0
	card_style.content_margin_top = 10.0
	card_style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", card_style)

	var col = VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(col)

	var discarded_label = _make_label("DISCARDED", 16, Color(0.5, 0.45, 0.35, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(discarded_label)

	var scroll_icon = _make_label("📜", 40, Color(0.4, 0.35, 0.25, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	col.add_child(scroll_icon)

	return card

func _build_option_pill(letter: String, text: String, text_color: Color, is_greyed: bool) -> PanelContainer:
	var pill = PanelContainer.new()
	var pill_style = StyleBoxFlat.new()
	pill_style.bg_color = COLOR_PILL_BG if not is_greyed else Color(0.0, 0.0, 0.0, 0.08)
	pill_style.corner_radius_top_left = 12
	pill_style.corner_radius_top_right = 12
	pill_style.corner_radius_bottom_left = 12
	pill_style.corner_radius_bottom_right = 12
	pill_style.content_margin_left = 10.0
	pill_style.content_margin_right = 10.0
	pill_style.content_margin_top = 6.0
	pill_style.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", pill_style)

	var pill_label = Label.new()
	pill_label.text = "%s: %s" % [letter, text]
	pill_label.add_theme_font_size_override("font_size", 14)
	pill_label.add_theme_color_override("font_color", text_color)
	pill_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pill_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill.add_child(pill_label)

	return pill

func reset_panel() -> void:
	_selected_policy_id = -1
	_last_ui_key = ""
	_card_nodes.clear()
	_confirm_section.visible = false
	for child in _cards_row.get_children():
		child.queue_free()

# --- callbacks ---

func _on_card_clicked(policy_id: int) -> void:
	_selected_policy_id = policy_id
	_last_ui_key = ""  # force rebuild

func _on_confirm_pressed() -> void:
	if _selected_policy_id >= 0:
		game_manager.discard_policy_by_id(_selected_policy_id)
		_selected_policy_id = -1
		_last_ui_key = ""  # force rebuild

func _on_cancel_pressed() -> void:
	_selected_policy_id = -1
	_last_ui_key = ""  # force rebuild

# --- helpers ---

func _make_label(text: String, font_size: int, color: Color, align: int) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _int_list(values: Array) -> String:
	var parts = []
	for v in values:
		parts.append(str(v))
	return ",".join(parts)
