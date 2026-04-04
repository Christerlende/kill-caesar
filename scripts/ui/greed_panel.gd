extends PanelContainer

## Full-screen Greed sequence after treasury failure (IDs must match GameManager GREED_* constants).

const PID_ROME_BURNS: int = 0
const PID_ASSASSINS_DOOR: int = 1
const PID_HEAVY_TAXES: int = 2
const PID_PENDULUM: int = 3
const PID_CAESAR_STEPS: int = 4
const PID_KNIVES_OUT: int = 5

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.75)
const COLOR_ASH = Color(0.55, 0.12, 0.1, 0.95)

const FADE_DELAY: float = 0.85
const FADE_DURATION: float = 0.9

const INTRO_LINES: Array = [
	"The senate's inaction creates unrest in all of Rome.",
	"The treasury doors slam shut — and the forums begin to whisper.",
	"While senators count coins, the city counts grievances.",
	"A republic that will not pay soon learns what anger costs.",
	"The grain of patience is spent; the people demand a reckoning.",
	"Silence in the chamber echoes louder than any speech.",
	"Rome watches gold sit still while hunger does not.",
	"The mob does not read decrees — it reads neglect.",
	"Inaction is a tax the poor never voted for.",
	"The peace of Rome frays where the senate will not spend.",
]

var game_manager = null

var _root: VBoxContainer
var _content: VBoxContainer
var _continue_btn: Button
var _tween: Tween = null
var _sequence_started: bool = false
var _last_phase_key: String = ""

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
	_root.add_theme_constant_override("separation", 20)
	_root.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_root)

	var title = Label.new()
	title.text = "GREED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", COLOR_ASH)
	_root.add_child(title)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 18)
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(_content)

	_continue_btn = Button.new()
	_continue_btn.text = "Continue"
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_on_continue_pressed)
	_continue_btn.add_theme_color_override("font_color", COLOR_CREAM)
	_root.add_child(_continue_btn)

func reset_panel() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	_sequence_started = false
	_last_phase_key = ""
	_continue_btn.visible = false
	for c in _content.get_children():
		c.queue_free()

func _process(_delta: float) -> void:
	if not game_manager:
		return
	var state = game_manager.state
	if not state:
		return
	var key = "%s|%d" % [state.game_phase, state.last_greed_punishment_id]
	if state.game_phase != "greed":
		if _last_phase_key != "" and state.game_phase != "greed":
			reset_panel()
		_last_phase_key = ""
		return
	if key == _last_phase_key and _sequence_started:
		return
	_last_phase_key = key
	if not _sequence_started:
		_start_sequence(state)

func _add_line(text: String, font_sz: int, color: Color) -> Label:
	var l = Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", font_sz)
	l.add_theme_color_override("font_color", color)
	l.modulate = Color(1, 1, 1, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(l)
	return l

func _start_sequence(state) -> void:
	_sequence_started = true
	for c in _content.get_children():
		c.queue_free()
	_continue_btn.visible = false

	var intro = INTRO_LINES[randi() % INTRO_LINES.size()]
	var pid = state.last_greed_punishment_id
	var lines: Array = _punishment_sequence(pid)

	var items: Array = []
	items.append({"node": _add_line(intro, 22, COLOR_CREAM), "apply": false})

	for entry in lines:
		var node = _add_line(entry["text"], entry["size"], entry["color"])
		items.append({"node": node, "apply": entry.get("apply", false)})

	if _tween:
		_tween.kill()
	_tween = create_tween()
	for item in items:
		_tween.tween_interval(FADE_DELAY)
		_tween.tween_property(item.node, "modulate:a", 1.0, FADE_DURATION).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		if item.apply:
			_tween.tween_callback(_apply_punishment.bind(pid))
	_tween.tween_interval(FADE_DELAY)
	_tween.tween_callback(_show_continue)

func _apply_punishment(punishment_id: int) -> void:
	if game_manager:
		game_manager.apply_greed_punishment(punishment_id)

func _show_continue() -> void:
	_continue_btn.visible = true
	_continue_btn.modulate = Color(1, 1, 1, 0)
	var bt = create_tween()
	bt.tween_property(_continue_btn, "modulate:a", 1.0, 0.45)

func _on_continue_pressed() -> void:
	if game_manager:
		game_manager.finish_greed_sequence()
	reset_panel()

func _punishment_sequence(pid: int) -> Array:
	var out: Array = []
	match pid:
		PID_ROME_BURNS:
			out.append({"text": "Rome burns.", "size": 28, "color": COLOR_ASH})
			out.append({"text": "The citizens revolt. Fires spread through the insulae and the markets. Repair will cost fortunes the senate would not spare.", "size": 18, "color": COLOR_CREAM})
			out.append({"text": "All senate representatives \"donate\" half their wealth (rounded up) to rebuild what was lost.", "size": 18, "color": COLOR_GOLD, "apply": true})
		PID_ASSASSINS_DOOR:
			out.append({"text": "Assassins at the door.", "size": 28, "color": COLOR_ASH})
			out.append({"text": "Desperation breeds blades. The senate turns on itself in the dark — not for principle, but for fear.", "size": 18, "color": COLOR_CREAM})
			out.append({"text": "Two random representatives receive an assassination token.", "size": 18, "color": COLOR_GOLD, "apply": true})
		PID_HEAVY_TAXES:
			out.append({"text": "Heavy taxes.", "size": 28, "color": COLOR_ASH})
			out.append({"text": "If the senate will not spend for Rome, the people will take more from the senate — early, and harsh.", "size": 18, "color": COLOR_CREAM})
			out.append({"text": "Heavy taxation applies… early. (Threshold 20 for three rounds.)", "size": 18, "color": COLOR_GOLD, "apply": true})
		PID_PENDULUM:
			out.append({"text": "The pendulum swings.", "size": 28, "color": COLOR_ASH})
			out.append({"text": "The mob tires of the dominant faction. They demand motion — any motion — toward something new.", "size": 18, "color": COLOR_CREAM})
			out.append({"text": "+2 Influence to the faction with less influence.", "size": 18, "color": COLOR_GOLD, "apply": true})
		PID_CAESAR_STEPS:
			out.append({"text": "Caesar steps forth.", "size": 28, "color": COLOR_ASH})
			out.append({"text": "Rome wearies of the old class war. A single figure gathers the spotlight — to the fury of patrician and plebeian alike.", "size": 18, "color": COLOR_CREAM})
			out.append({"text": "Caesar gains 15 gold and one mark on the plot against him (if below two marks).", "size": 18, "color": COLOR_GOLD, "apply": true})
		PID_KNIVES_OUT:
			out.append({"text": "Knives out.", "size": 28, "color": COLOR_ASH})
			out.append({"text": "Every hand reaches for a blade. No one trusts the next bench — only the steel they can hide.", "size": 18, "color": COLOR_CREAM})
			out.append({"text": "Each representative who can receives an assassination token.", "size": 18, "color": COLOR_GOLD, "apply": true})
		_:
			out.append({"text": "The republic shudders.", "size": 22, "color": COLOR_CREAM, "apply": true})
	return out
