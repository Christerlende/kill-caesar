extends Control

## Shows the local player their secret role before the game begins.
## In online mode each player sees only their own role on their own screen.
## Humans must all acknowledge before anyone loads the main game; AI seats skip this step.

const GameManager = preload("res://scripts/game/game_manager.gd")
const Role = preload("res://scripts/data/role.gd").Role

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)
const COLOR_RED = Color(0.76, 0.16, 0.12, 1)
const COLOR_BLUE = Color(0.2, 0.36, 0.82, 1)

const ROLE_REVEAL_DELAY: float = 1.2
const DETAIL_REVEAL_DELAY: float = 2.4

var _my_seat: int = -1
var _my_role: int = Role.PLEBIAN
var _player_name: String = ""
var _assigned_roles: Array = []
var _player_names: Array = []

var _heading_label: Label
var _role_label: Label
var _detail_label: Label
var _enter_button: Button
var _waiting_label: Label
var _reveal_time: float = 0.0
var _role_shown: bool = false
var _details_shown: bool = false

func _ready() -> void:
	_load_game_data()
	_build_ui()
	_reveal_time = 0.0
	_role_shown = false
	_details_shown = false

func _process(delta: float) -> void:
	if _details_shown:
		return
	_reveal_time += delta
	if not _role_shown and _reveal_time >= ROLE_REVEAL_DELAY:
		_role_shown = true
		_show_role()
	if _role_shown and not _details_shown and _reveal_time >= DETAIL_REVEAL_DELAY:
		_details_shown = true
		_show_details()
		_enter_button.visible = true
		_enter_button.modulate = Color(1, 1, 1, 0)
		var tween = create_tween()
		tween.tween_property(_enter_button, "modulate:a", 1.0, 0.5)

func _load_game_data() -> void:
	_assigned_roles = GameManager.queued_player_roles.duplicate()
	_player_names = GameManager.queued_player_names.duplicate()
	var nm = get_node_or_null("/root/NetworkManager")
	if nm:
		var sorted = nm.get_sorted_peer_ids()
		var my_peer = nm.get_my_peer_id()
		for i in range(sorted.size()):
			if sorted[i] == my_peer:
				_my_seat = i
				break
	if _my_seat < 0:
		_my_seat = 0
	if _my_seat < _assigned_roles.size():
		_my_role = _assigned_roles[_my_seat]
	if _my_seat < _player_names.size():
		_player_name = _player_names[_my_seat]
	else:
		_player_name = "Player %d" % (_my_seat + 1)

func _build_ui() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.04, 0.02, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(700, 0)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.06, 0.04, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.7, 0.55, 0.2, 0.7)
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel_style.content_margin_left = 40.0
	panel_style.content_margin_right = 40.0
	panel_style.content_margin_top = 36.0
	panel_style.content_margin_bottom = 36.0
	panel.add_theme_stylebox_override("panel", panel_style)
	center.add_child(panel)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	panel.add_child(vbox)

	_heading_label = Label.new()
	_heading_label.text = "Your Secret Role, %s" % _player_name
	_heading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_heading_label.add_theme_font_size_override("font_size", 36)
	_heading_label.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(_heading_label)

	var sep = HSeparator.new()
	vbox.add_child(sep)

	_role_label = Label.new()
	_role_label.text = "..."
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.add_theme_font_size_override("font_size", 42)
	_role_label.add_theme_color_override("font_color", COLOR_CREAM)
	vbox.add_child(_role_label)

	_detail_label = Label.new()
	_detail_label.text = ""
	_detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_detail_label.add_theme_font_size_override("font_size", 18)
	_detail_label.add_theme_color_override("font_color", COLOR_CREAM)
	_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_label.custom_minimum_size = Vector2(600, 0)
	vbox.add_child(_detail_label)

	_enter_button = Button.new()
	_enter_button.text = "Enter the Senate"
	_enter_button.custom_minimum_size = Vector2(0, 56)
	_enter_button.visible = false
	_enter_button.pressed.connect(_on_enter_pressed)
	_enter_button.add_theme_color_override("font_color", COLOR_CREAM)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.14, 0.62, 0.18, 0.95)
	btn_style.border_width_left = 1
	btn_style.border_width_top = 1
	btn_style.border_width_right = 1
	btn_style.border_width_bottom = 1
	btn_style.border_color = Color(0.78, 0.9, 0.78, 0.7)
	btn_style.corner_radius_top_left = 6
	btn_style.corner_radius_top_right = 6
	btn_style.corner_radius_bottom_left = 6
	btn_style.corner_radius_bottom_right = 6
	btn_style.content_margin_left = 20
	btn_style.content_margin_right = 20
	btn_style.content_margin_top = 10
	btn_style.content_margin_bottom = 10
	_enter_button.add_theme_stylebox_override("normal", btn_style)
	_enter_button.add_theme_stylebox_override("focus", btn_style)
	_enter_button.add_theme_stylebox_override("pressed", btn_style)
	_enter_button.add_theme_stylebox_override("hover", btn_style)
	vbox.add_child(_enter_button)

	_waiting_label = Label.new()
	_waiting_label.text = "Waiting for other representatives…"
	_waiting_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_waiting_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_waiting_label.custom_minimum_size = Vector2(600, 0)
	_waiting_label.visible = false
	_waiting_label.add_theme_font_size_override("font_size", 22)
	_waiting_label.add_theme_color_override("font_color", COLOR_DIM)
	_waiting_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_waiting_label)

func _show_role() -> void:
	_role_label.text = _role_display_name(_my_role)
	match _my_role:
		Role.CAESAR:
			_role_label.add_theme_color_override("font_color", COLOR_GOLD)
		Role.PATRICIAN:
			_role_label.add_theme_color_override("font_color", COLOR_RED)
		_:
			_role_label.add_theme_color_override("font_color", COLOR_BLUE)

func _show_details() -> void:
	match _my_role:
		Role.PLEBIAN:
			_detail_label.text = "You step into Roman politics with no guaranteed allies. Watch your back: daggers are often hidden behind speeches."
		Role.PATRICIAN:
			var ally_name = "Unknown"
			for i in range(_assigned_roles.size()):
				if i != _my_seat and _assigned_roles[i] == Role.PATRICIAN:
					ally_name = _get_name(i)
					break
			_detail_label.text = "Your fellow Patrician Representative is %s.\nStand as nobles of Rome, and do not let the plebeian representatives shake your resolve." % ally_name
		Role.CAESAR:
			var lines: Array = ["All senate roles are now known to you:"]
			for i in range(_assigned_roles.size()):
				lines.append("%s — %s" % [_get_name(i), _role_display_name(_assigned_roles[i])])
			lines.append("")
			lines.append("Lead the republic with balance and authority. Rome watches your every decree.")
			_detail_label.text = "\n".join(lines)

func _get_name(index: int) -> String:
	if index < 0 or index >= _player_names.size():
		return "Player %d" % (index + 1)
	var n = str(_player_names[index]).strip_edges()
	if n == "":
		return "Player %d" % (index + 1)
	return n

func _role_display_name(role: int) -> String:
	match role:
		Role.CAESAR:
			return "Caesar"
		Role.PATRICIAN:
			return "Patrician Representative"
		_:
			return "Plebeian Representative"

func _on_enter_pressed() -> void:
	_enter_button.visible = false
	_waiting_label.visible = true

	var nm = get_node_or_null("/root/NetworkManager")
	if nm == null or not nm.is_online:
		get_tree().change_scene_to_file("res://scenes/game.tscn")
		return

	nm.notify_role_reveal_acknowledged()
