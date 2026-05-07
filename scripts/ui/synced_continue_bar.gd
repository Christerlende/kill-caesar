extends HBoxContainer
## Host-synced Continue control: countdown on button, local ready + global x/n after click.

const GameManager = preload("res://scripts/game/game_manager.gd")

const COLOR_CREAM := Color(0.95, 0.92, 0.85, 1)

var game_manager = null
## One of GameManager.CONTINUE_GATE_* (must match GameState.continue_gate_kind while active).
var expected_gate_kind: int = GameManager.CONTINUE_GATE_NONE

var _button: Button
var _ready_label: Label
var _local_clicked: bool = false
var _last_seen_gate_id: int = 0

func _ready() -> void:
	alignment = ALIGNMENT_CENTER
	add_theme_constant_override("separation", 14)
	size_flags_horizontal = SIZE_SHRINK_CENTER
	_button = Button.new()
	_button.text = "Continue"
	_button.pressed.connect(_on_pressed)
	_apply_continue_button_style(_button)
	add_child(_button)
	_ready_label = Label.new()
	_ready_label.visible = false
	_ready_label.add_theme_font_size_override("font_size", 17)
	_ready_label.add_theme_color_override("font_color", Color(0.6, 0.55, 0.45, 0.85))
	add_child(_ready_label)

func reset_local_state() -> void:
	_local_clicked = false
	_last_seen_gate_id = 0

func _on_pressed() -> void:
	if game_manager == null or _local_clicked:
		return
	_local_clicked = true
	game_manager.submit_continue_ready()

func _process(_delta: float) -> void:
	if game_manager == null or game_manager.state == null:
		visible = false
		return
	var st = game_manager.state
	if st.continue_gate_kind != expected_gate_kind:
		if _last_seen_gate_id != 0:
			reset_local_state()
		visible = false
		return
	var seat: int = game_manager.get_continue_actor_seat()
	if seat < 0 or seat >= st.players.size():
		visible = false
		return
	var pl = st.players[seat]
	if pl.is_dead or pl.is_ai:
		visible = false
		return
	visible = true
	var gid: int = st.continue_gate_id
	if gid != _last_seen_gate_id:
		_last_seen_gate_id = gid
		_local_clicked = false
	var now: int = Time.get_ticks_msec()
	var secs_left: int = maxi(0, int(ceil(float(st.continue_deadline_msec - now) / 1000.0)))
	var total: int = game_manager.continue_living_total()
	var ready_n: int = game_manager.continue_living_ready_count()
	if _local_clicked:
		_button.disabled = true
		_button.text = "Continue"
		_ready_label.visible = true
		_ready_label.text = "%d / %d ready" % [ready_n, total]
	else:
		_button.disabled = false
		_button.text = "Continue (%d)" % maxi(0, secs_left)
		_ready_label.visible = false

func _apply_continue_button_style(btn: Button) -> void:
	btn.add_theme_color_override("font_color", COLOR_CREAM)
	btn.add_theme_color_override("font_focus_color", COLOR_CREAM)
	btn.add_theme_color_override("font_hover_color", COLOR_CREAM)
	btn.add_theme_color_override("font_pressed_color", COLOR_CREAM)
	var cs := StyleBoxFlat.new()
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
