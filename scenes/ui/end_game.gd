extends Control

const GameManager = preload("res://scripts/game/game_manager.gd")
const Role = preload("res://scripts/data/role.gd").Role

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)
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

	var is_caesar_win = false

	# Check if Caesar caused the win (Caesar is on the Patrician team)
	# Caesar wins if Patricians win
	if winner == "Patricians":
		# Check if there's a Caesar in the game
		for p in GameManager.last_player_roles:
			if p.role == Role.CAESAR:
				is_caesar_win = true
				break

	if is_caesar_win:
		_winner_label.text = "Caesar Wins!"
	else:
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
		var tween_c = create_tween()
		tween_c.tween_interval(1.2)
		tween_c.tween_property(collapse_body, "modulate:a", 1.0, 0.9).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween_c.tween_interval(1.5)
		tween_c.tween_property(_closing_label, "modulate:a", 1.0, 0.8)
		tween_c.tween_interval(0.4)
		tween_c.tween_property(_buttons_box, "modulate:a", 1.0, 0.5)
		return

	var players = GameManager.last_player_roles

	# Sort players into groups
	var winning_players: Array = []
	var losing_players: Array = []
	var caesar_player: Dictionary = {}

	if winner == "Patricians":
		for p in players:
			if p.role == Role.CAESAR:
				caesar_player = p
			elif p.role == Role.PATRICIAN:
				winning_players.append(p)
			else:
				losing_players.append(p)
	else:  # Plebeians win
		for p in players:
			if p.role == Role.CAESAR:
				caesar_player = p
			elif p.role == Role.PLEBIAN:
				winning_players.append(p)
			else:
				losing_players.append(p)

	# Build reveal labels
	var winner_names = _format_player_names(winning_players)
	var loser_names = _format_player_names(losing_players)
	var caesar_name = "Player %d" % (caesar_player.player_id + 1) if caesar_player.size() > 0 else "Unknown"

	var winning_role = "Patricians" if winner == "Patricians" else "Plebeians"
	var losing_role = "Plebeians" if winner == "Patricians" else "Patricians"

	_winners_label = _make_reveal_label(
		"%s: %s have seized control of Rome." % [winning_role, winner_names],
		COLOR_GOLD
	)
	_reveal_box.add_child(_winners_label)

	_losers_label = _make_reveal_label(
		"%s: %s." % [losing_role, loser_names],
		COLOR_DIM
	)
	_reveal_box.add_child(_losers_label)

	_caesar_label = _make_reveal_label(
		"Caesar: %s." % caesar_name,
		COLOR_RED
	)
	_reveal_box.add_child(_caesar_label)

	# Tween chain
	var tween = create_tween()

	# t=2s: Reveal winners
	tween.tween_interval(2.0)
	tween.tween_property(_winners_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# t=4s: Reveal losers
	tween.tween_interval(1.2)
	tween.tween_property(_losers_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# t=5s: Reveal Caesar
	tween.tween_interval(0.2)
	tween.tween_property(_caesar_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

	# t=8s: Closing text + buttons
	tween.tween_interval(2.2)
	tween.tween_property(_closing_label, "modulate:a", 1.0, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.5)
	tween.tween_property(_buttons_box, "modulate:a", 1.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _format_player_names(players: Array) -> String:
	var names: Array = []
	for p in players:
		names.append("Player %d" % (p.player_id + 1))
	if names.size() == 0:
		return "None"
	if names.size() == 1:
		return names[0]
	return ", ".join(names.slice(0, names.size() - 1)) + " & " + names[names.size() - 1]

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
