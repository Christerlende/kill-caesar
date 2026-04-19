extends Control

const GameManager = preload("res://scripts/game/game_manager.gd")
const Role = preload("res://scripts/data/role.gd").Role

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)
const COLOR_DEAD = Color(0.45, 0.42, 0.40, 0.75)
const COLOR_RED = Color(0.76, 0.16, 0.12, 1)
const COLOR_BLUE = Color(0.2, 0.36, 0.82, 1)

var _winner_label: Label
var _score_label: Label
var _reveal_box: VBoxContainer
var _closing_label: Label
var _buttons_box: HBoxContainer

# Reveal items (created dynamically)
var _winners_label: Label
var _losers_label: Label
var _caesar_label: Label

func _ready() -> void:
	# Build UI from scratch (ignore scene nodes)
	_clear_children()

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.04, 0.02, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	vbox.custom_minimum_size = Vector2(700, 0)
	center.add_child(vbox)

	# Winner title
	_winner_label = Label.new()
	_winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_winner_label.add_theme_font_size_override("font_size", 52)
	_winner_label.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(_winner_label)

	# Influence score
	_score_label = Label.new()
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_score_label.add_theme_font_size_override("font_size", 20)
	_score_label.add_theme_color_override("font_color", COLOR_CREAM)
	vbox.add_child(_score_label)

	# Spacer
	var spacer = Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Role reveal area
	_reveal_box = VBoxContainer.new()
	_reveal_box.add_theme_constant_override("separation", 16)
	_reveal_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_reveal_box)

	# Closing text
	_closing_label = Label.new()
	_closing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_closing_label.add_theme_font_size_override("font_size", 24)
	_closing_label.add_theme_color_override("font_color", COLOR_GOLD)
	_closing_label.modulate = Color(1, 1, 1, 0)
	vbox.add_child(_closing_label)

	# Buttons (hidden until closing text)
	_buttons_box = HBoxContainer.new()
	_buttons_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons_box.add_theme_constant_override("separation", 16)
	_buttons_box.modulate = Color(1, 1, 1, 0)
	vbox.add_child(_buttons_box)

	var play_again_btn = _build_button("Play Again")
	play_again_btn.pressed.connect(_on_play_again)
	_buttons_box.add_child(play_again_btn)

	var main_menu_btn = _build_button("Main Menu")
	main_menu_btn.pressed.connect(_on_main_menu)
	_buttons_box.add_child(main_menu_btn)

	# Populate content
	_populate()
	_start_reveal_sequence()

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()

func _populate() -> void:
	var winner = GameManager.last_winner_text

	if winner == "collapse":
		_winner_label.text = "Rome has fallen"
		_score_label.text = "Patrician Influence: %d  |  Plebeian Influence: %d" % [
			GameManager.last_patrician_influence,
			GameManager.last_plebian_influence
		]
		_closing_label.text = "No faction claims the ruins. The republic ends not with a blade, but with a shrug."
		return

	if winner == "Caesar":
		_winner_label.text = "Caesar Wins!"
		_score_label.text = "Patrician Influence: %d  |  Plebeian Influence: %d" % [
			GameManager.last_patrician_influence,
			GameManager.last_plebian_influence
		]
		_closing_label.text = "Vae victis. The Republic is dead; the Empire begins."
		return

	_winner_label.text = "%s Win!" % winner
	_score_label.text = "Patrician Influence: %d  |  Plebeian Influence: %d" % [
		GameManager.last_patrician_influence,
		GameManager.last_plebian_influence
	]
	_closing_label.text = "Sic semper res publica. May Rome endure."

func _start_reveal_sequence() -> void:
	var winner = GameManager.last_winner_text

	if winner == "collapse":
		for child in _reveal_box.get_children():
			child.queue_free()
		var collapse_body = _make_reveal_label(
			"Rome collapses under the weight of the senate's indecision. Again and again the treasury stood empty; again and again the people were ignored. There are no victors — only ash.",
			COLOR_DIM
		)
		_reveal_box.add_child(collapse_body)
		var full_reveal_nodes_c: Array = _build_full_reveal_rows()
		var tween_c = create_tween()
		tween_c.tween_interval(1.2)
		tween_c.tween_property(collapse_body, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		for node in full_reveal_nodes_c:
			tween_c.tween_interval(0.45)
			tween_c.tween_property(node, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween_c.tween_interval(1.2)
		tween_c.tween_property(_closing_label, "modulate:a", 1.0, 0.8)
		tween_c.tween_interval(0.4)
		tween_c.tween_property(_buttons_box, "modulate:a", 1.0, 0.5)
		return

	var snapshots = _get_snapshots()

	# Top-of-reveal headline row(s) grouped by side.
	var headline_tween_nodes: Array = []

	if winner == "Caesar":
		var caesar_snap = _find_snapshot_by_role(snapshots, Role.CAESAR)
		var caesar_name = _snapshot_display_name(caesar_snap)
		var headline = _make_reveal_label(
			"Caesar: %s has seized Rome." % caesar_name,
			COLOR_GOLD
		)
		_reveal_box.add_child(headline)
		headline_tween_nodes.append(headline)

		var override_faction: String = GameManager.last_caesar_override_faction
		var sub_text: String
		if override_faction != "":
			sub_text = "The %s were within a breath of victory — but Caesar took the final vote for himself." % override_faction
		else:
			sub_text = "Three times the senate bowed. Three times Caesar slipped through the doors of power."
		var sub_label = _make_reveal_label(sub_text, COLOR_CREAM)
		_reveal_box.add_child(sub_label)
		headline_tween_nodes.append(sub_label)
	else:
		var winning_role_id: int = Role.PATRICIAN if winner == "Patricians" else Role.PLEBIAN
		var losing_role_id: int = Role.PLEBIAN if winner == "Patricians" else Role.PATRICIAN
		var winners_snaps: Array = _filter_snapshots_by_role(snapshots, winning_role_id)
		var losers_snaps: Array = _filter_snapshots_by_role(snapshots, losing_role_id)
		var caesar_snap2 = _find_snapshot_by_role(snapshots, Role.CAESAR)

		var winning_role_name = "Patricians" if winner == "Patricians" else "Plebeians"
		var losing_role_name = "Plebeians" if winner == "Patricians" else "Patricians"

		_winners_label = _make_reveal_label(
			"%s: %s have seized control of Rome." % [winning_role_name, _format_snapshot_names(winners_snaps)],
			COLOR_GOLD
		)
		_reveal_box.add_child(_winners_label)
		headline_tween_nodes.append(_winners_label)

		_losers_label = _make_reveal_label(
			"%s: %s." % [losing_role_name, _format_snapshot_names(losers_snaps)],
			COLOR_DIM
		)
		_reveal_box.add_child(_losers_label)
		headline_tween_nodes.append(_losers_label)

		if caesar_snap2.size() > 0:
			_caesar_label = _make_reveal_label(
				"Caesar: %s." % _snapshot_display_name(caesar_snap2),
				COLOR_RED
			)
			_reveal_box.add_child(_caesar_label)
			headline_tween_nodes.append(_caesar_label)

	# Full reveal: every player's role, purse, assassin token.
	var full_reveal_nodes: Array = _build_full_reveal_rows()

	# Tween chain.
	var tween = create_tween()

	# Initial pause before the first headline.
	tween.tween_interval(1.6)
	for i in range(headline_tween_nodes.size()):
		if i > 0:
			tween.tween_interval(1.0)
		tween.tween_property(headline_tween_nodes[i], "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Full per-player reveal — each row fades in in sequence.
	for node in full_reveal_nodes:
		tween.tween_interval(0.45)
		tween.tween_property(node, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# Closing text + buttons.
	tween.tween_interval(1.6)
	tween.tween_property(_closing_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.5)
	tween.tween_property(_buttons_box, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _get_snapshots() -> Array:
	if GameManager.last_player_snapshots.size() > 0:
		return GameManager.last_player_snapshots
	## Back-compat fallback: older code paths only stored last_player_roles.
	var fallback: Array = []
	for p in GameManager.last_player_roles:
		fallback.append({
			"player_id": p.player_id,
			"role": p.role,
			"role_name": p.get("role_name", ""),
			"display_name": "Player %d" % (p.player_id + 1),
			"money": 0,
			"available_assassination_tokens": 0,
			"co_consul_count": 0,
			"is_dead": false,
		})
	return fallback

func _filter_snapshots_by_role(snapshots: Array, role_id: int) -> Array:
	var out: Array = []
	for s in snapshots:
		if s.role == role_id:
			out.append(s)
	return out

func _find_snapshot_by_role(snapshots: Array, role_id: int) -> Dictionary:
	for s in snapshots:
		if s.role == role_id:
			return s
	return {}

func _snapshot_display_name(snap: Dictionary) -> String:
	if snap.size() == 0:
		return "Unknown"
	var name_str: String = str(snap.get("display_name", "")).strip_edges()
	if name_str == "":
		name_str = "Player %d" % (int(snap.get("player_id", 0)) + 1)
	return name_str

func _format_snapshot_names(snapshots: Array) -> String:
	var names: Array = []
	for s in snapshots:
		names.append(_snapshot_display_name(s))
	if names.size() == 0:
		return "None"
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " & " + names[names.size() - 1]

func _role_color(role: int) -> Color:
	match role:
		Role.CAESAR:
			return COLOR_GOLD
		Role.PATRICIAN:
			return COLOR_RED
		Role.PLEBIAN:
			return COLOR_BLUE
		_:
			return COLOR_CREAM

func _role_label_name(role: int) -> String:
	match role:
		Role.CAESAR:
			return "Caesar"
		Role.PATRICIAN:
			return "Patrician"
		Role.PLEBIAN:
			return "Plebeian"
		_:
			return "Unknown"

func _build_full_reveal_rows() -> Array:
	var snapshots = _get_snapshots()
	if snapshots.is_empty():
		return []

	var section_header = Label.new()
	section_header.text = "— The Senate Revealed —"
	section_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	section_header.add_theme_font_size_override("font_size", 18)
	section_header.add_theme_color_override("font_color", COLOR_GOLD)
	section_header.modulate = Color(1, 1, 1, 0)
	_reveal_box.add_child(section_header)

	var rows: Array = [section_header]
	for snap in snapshots:
		var row = _build_player_reveal_row(snap)
		_reveal_box.add_child(row)
		rows.append(row)
	return rows

func _build_player_reveal_row(snap: Dictionary) -> Control:
	var is_dead: bool = bool(snap.get("is_dead", false))
	var role_id: int = int(snap.get("role", Role.PLEBIAN))
	var row = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.modulate = Color(1, 1, 1, 0)

	var name_label = Label.new()
	name_label.text = _snapshot_display_name(snap)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.add_theme_color_override("font_color", COLOR_DEAD if is_dead else COLOR_CREAM)
	name_label.custom_minimum_size = Vector2(160, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(name_label)

	var role_label = Label.new()
	var role_text: String = _role_label_name(role_id)
	if is_dead:
		role_text += " (dead)"
	role_label.text = role_text
	role_label.add_theme_font_size_override("font_size", 15)
	role_label.add_theme_color_override("font_color", COLOR_DEAD if is_dead else _role_color(role_id))
	role_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(role_label)

	var purse_label = Label.new()
	purse_label.text = "Purse: %d gold" % int(snap.get("money", 0))
	purse_label.add_theme_font_size_override("font_size", 15)
	purse_label.add_theme_color_override("font_color", COLOR_DEAD if is_dead else COLOR_GOLD)
	purse_label.custom_minimum_size = Vector2(140, 0)
	row.add_child(purse_label)

	var token_label = Label.new()
	var tokens_held: int = int(snap.get("available_assassination_tokens", 0))
	token_label.text = "Assassin token: %s" % ("yes" if tokens_held > 0 else "no")
	token_label.add_theme_font_size_override("font_size", 15)
	token_label.add_theme_color_override("font_color", COLOR_DEAD if is_dead else (COLOR_RED if tokens_held > 0 else COLOR_DIM))
	token_label.custom_minimum_size = Vector2(160, 0)
	row.add_child(token_label)

	return row

func _make_reveal_label(text: String, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(1, 1, 1, 0)
	return l

func _build_button(text: String) -> Button:
	var btn = Button.new()
	btn.text = text
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

func _on_play_again() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_main_menu() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
