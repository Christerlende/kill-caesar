extends PanelContainer

const Role = preload("res://scripts/data/role.gd").Role

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM = Color(0.6, 0.55, 0.45, 0.7)

var game_manager = null

var _round_label: Label
var _flavor_label: Label
var _consul_label: Label
var _animation_played: bool = false
var _last_flavor_index: int = -1
var _sequence_id: int = 0

const FIRST_ROUND_TEXT: String = "A senator rises to claim the mantle of consul."

const FLAVOR_TEXTS: Array = [
	"A new voice echoes through the senate. Another steps forward to lead.",
	"The senate stirs as a fresh claimant approaches the ivory chair.",
	"Ambition fills the chamber. A new consul demands to be heard.",
	"The toga praetexta awaits its next bearer.",
	"Rome turns its gaze upon a new champion of the republic.",
	"The fasces are raised. A new hand reaches for power.",
	"Another senator ascends the rostra, eyes set on the consulship.",
	"The wheel of fortune turns. A new leader emerges from the ranks.",
	"Whispers ripple through the marble halls. A contender has arrived.",
	"The eagles watch as another soul dares to shape Rome's destiny.",
	"From the benches of the curia, a bold figure rises to speak.",
	"The Capitoline hums with anticipation. A new consul approaches.",
	"Power shifts like sand. Another senator seizes the moment.",
	"The senate floor trembles beneath the stride of a new aspirant.",
	"By Jupiter's will, a fresh voice rings out across the forum.",
]

func _ready() -> void:
	clip_contents = true

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.04, 0.02, 0.97)
	add_theme_stylebox_override("panel", style)

	var center = CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(center)

	var vbox = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	_round_label = Label.new()
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.add_theme_font_size_override("font_size", 48)
	_round_label.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(_round_label)

	_flavor_label = Label.new()
	_flavor_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flavor_label.add_theme_font_size_override("font_size", 22)
	_flavor_label.add_theme_color_override("font_color", COLOR_CREAM)
	_flavor_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_flavor_label.custom_minimum_size = Vector2(600, 0)
	vbox.add_child(_flavor_label)

	_consul_label = Label.new()
	_consul_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_consul_label.add_theme_font_size_override("font_size", 30)
	_consul_label.add_theme_color_override("font_color", COLOR_GOLD)
	vbox.add_child(_consul_label)

func show_round(round_number: int, consul_name: String) -> void:
	_sequence_id += 1
	_animation_played = false

	_round_label.text = "Round %d" % round_number

	if round_number == 1:
		_flavor_label.text = FIRST_ROUND_TEXT
	else:
		var idx = randi() % FLAVOR_TEXTS.size()
		if idx == _last_flavor_index:
			idx = (idx + 1) % FLAVOR_TEXTS.size()
		_last_flavor_index = idx
		_flavor_label.text = FLAVOR_TEXTS[idx]

	_consul_label.text = consul_name

	# Start all invisible then fade in
	_round_label.modulate = Color(1, 1, 1, 0)
	_flavor_label.modulate = Color(1, 1, 1, 0)
	_consul_label.modulate = Color(1, 1, 1, 0)

	_play_entrance_animation(_sequence_id)

func _play_entrance_animation(sequence_id: int) -> void:
	if _animation_played:
		return
	_animation_played = true

	var tween = create_tween()
	# Fade in round number
	tween.tween_property(_round_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Pause then flavor text
	tween.tween_interval(0.4)
	tween.tween_property(_flavor_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# Pause then consul name
	tween.tween_interval(0.4)
	tween.tween_property(_consul_label, "modulate:a", 1.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	# 2 seconds after consul reveal, auto-progress to election
	tween.tween_interval(2.0)
	tween.tween_callback(_auto_advance.bind(sequence_id))

func _auto_advance(sequence_id: int) -> void:
	if sequence_id != _sequence_id:
		return
	if not game_manager or not game_manager.state:
		return
	if game_manager.state.game_phase != "round_start":
		return
	game_manager.progress()

func reset_panel() -> void:
	_sequence_id += 1
	_animation_played = false
