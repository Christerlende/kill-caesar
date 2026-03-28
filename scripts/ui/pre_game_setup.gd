extends Control

const Role = preload("res://scripts/data/role.gd").Role

const PLAYER_COUNT: int = 6
const ROLE_REVEAL_DELAY: float = 1.0
const DETAIL_REVEAL_DELAY: float = 2.0
const NAME_TITLE_VARIANTS: Array = [
	"Enter the Senate",
	"Approach the Curia",
	"Stand Before the Fathers",
	"Take the Marble Floor",
	"Speak Before the Eagles",
	"Claim Thy Place in Rome",
]
const NAME_BODY_VARIANTS: Array = [
	"Player %d, state your name before stepping into Roman politics.",
	"Player %d, declare your name. The senate listens.",
	"Player %d, let Rome hear how you are called.",
	"Player %d, mark your name in the memory of the republic.",
	"Player %d, speak your name and enter the chamber.",
	"Player %d, present yourself to the senators of Rome.",
]
const READY_TEXT_VARIANTS: Array = [
	"Ready",
	"To the next petitioner",
	"Summon the next senator",
	"Proceed",
]

@onready var name_panel: PanelContainer = $CenterContainer/NamePanel
@onready var name_title_label: Label = $CenterContainer/NamePanel/Margin/VBox/TitleLabel
@onready var name_body_label: Label = $CenterContainer/NamePanel/Margin/VBox/BodyLabel
@onready var name_input: LineEdit = $CenterContainer/NamePanel/Margin/VBox/NameInput
@onready var name_confirm_button: Button = $CenterContainer/NamePanel/Margin/VBox/NameButtonRow/NameConfirmButton
@onready var name_feedback_label: Label = $CenterContainer/NamePanel/Margin/VBox/NameFeedbackLabel

@onready var reveal_panel: PanelContainer = $CenterContainer/RevealPanel
@onready var reveal_heading_label: Label = $CenterContainer/RevealPanel/Margin/VBox/RevealHeadingLabel
@onready var reveal_role_label: Label = $CenterContainer/RevealPanel/Margin/VBox/RevealRoleLabel
@onready var reveal_detail_label: Label = $CenterContainer/RevealPanel/Margin/VBox/RevealDetailLabel
@onready var reveal_ready_button: Button = $CenterContainer/RevealPanel/Margin/VBox/RevealReadyButton

var _current_player_index: int = 0
var _player_names: Array = []
var _assigned_roles: Array = []
var _reveal_role: int = Role.PLEBIAN
var _reveal_time: float = 0.0
var _role_shown: bool = false
var _details_shown: bool = false

func _ready() -> void:
	randomize()
	_prepare_match_roles()
	_prepare_name_slots()
	_show_name_panel()

	name_confirm_button.pressed.connect(_on_name_confirm_pressed)
	reveal_ready_button.pressed.connect(_on_reveal_ready_pressed)
	name_input.text_submitted.connect(_on_name_submitted)

func _process(delta: float) -> void:
	if not reveal_panel.visible:
		return

	if _details_shown:
		return

	_reveal_time += delta

	if not _role_shown and _reveal_time >= ROLE_REVEAL_DELAY:
		_reveal_role_text()
		_role_shown = true
		if _reveal_role == Role.PLEBIAN:
			_reveal_plebeian_details()
			_details_shown = true
			reveal_ready_button.disabled = false
			return

	if _role_shown and _reveal_time >= DETAIL_REVEAL_DELAY:
		if _reveal_role == Role.PATRICIAN:
			_reveal_patrician_details()
		elif _reveal_role == Role.CAESAR:
			_reveal_caesar_details()
		_details_shown = true
		reveal_ready_button.disabled = false

func _prepare_match_roles() -> void:
	var roles = [
		Role.CAESAR,
		Role.PATRICIAN,
		Role.PATRICIAN,
		Role.PLEBIAN,
		Role.PLEBIAN,
		Role.PLEBIAN,
	]
	roles.shuffle()
	_assigned_roles = roles

	# Queue this distribution so the game scene uses the same roles.
	var game_manager_script = load("res://scripts/game/game_manager.gd")
	if game_manager_script:
		game_manager_script.set("queued_player_roles", _assigned_roles.duplicate())

func _prepare_name_slots() -> void:
	_player_names.clear()
	for i in range(PLAYER_COUNT):
		_player_names.append("Player %d" % (i + 1))

func _show_name_panel() -> void:
	name_panel.visible = true
	reveal_panel.visible = false
	reveal_ready_button.disabled = true
	name_feedback_label.text = ""
	name_title_label.text = _name_title_for_player(_current_player_index)
	name_body_label.text = _name_body_for_player(_current_player_index)
	name_input.clear()
	name_input.grab_focus()

func _show_reveal_panel() -> void:
	_reveal_role = _assigned_roles[_current_player_index]
	name_panel.visible = false
	reveal_panel.visible = true
	reveal_heading_label.text = "Secret Role - %s" % _display_name_for_heading(_current_player_index)
	reveal_role_label.text = "..."
	reveal_detail_label.text = ""
	reveal_ready_button.disabled = true
	reveal_ready_button.text = _ready_text_for_player(_current_player_index)

	_reveal_time = 0.0
	_role_shown = false
	_details_shown = false

func _on_name_confirm_pressed() -> void:
	var candidate_name = name_input.text.strip_edges()
	if candidate_name == "":
		name_feedback_label.text = "Rome demands a proper name before you enter the senate."
		return

	_player_names[_current_player_index] = candidate_name
	name_feedback_label.text = "Rome records your name, %s." % candidate_name
	_show_reveal_panel()

func _on_name_submitted(submitted_text: String) -> void:
	name_input.text = submitted_text
	_on_name_confirm_pressed()

func _queue_player_names() -> void:
	var game_manager_script = load("res://scripts/game/game_manager.gd")
	if game_manager_script:
		game_manager_script.set("queued_player_names", _player_names.duplicate())

func _on_reveal_ready_pressed() -> void:
	if _current_player_index < PLAYER_COUNT - 1:
		_current_player_index += 1
		_show_name_panel()
		return
	_queue_player_names()
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _reveal_role_text() -> void:
	reveal_role_label.text = _role_display_name(_reveal_role)

func _reveal_plebeian_details() -> void:
	reveal_detail_label.text = "You step into Roman politics with no guaranteed allies. Watch your back: daggers are often hidden behind speeches."

func _reveal_patrician_details() -> void:
	var ally_text = "Unknown"
	for i in range(_assigned_roles.size()):
		if i != _current_player_index and _assigned_roles[i] == Role.PATRICIAN:
			ally_text = _player_slot_name(i)
			break
	reveal_detail_label.text = "Your fellow Patrician Representative is %s.\nStand as nobles of Rome, and do not let the plebeian representatives shake your resolve." % ally_text

func _reveal_caesar_details() -> void:
	var lines: Array = ["All senate roles are now known to you:"]
	for i in range(_assigned_roles.size()):
		lines.append("%s - %s" % [_player_slot_name(i), _role_display_name(_assigned_roles[i])])
	lines.append("")
	lines.append("Lead the republic with balance and authority. Rome watches your every decree.")
	reveal_detail_label.text = "\n".join(lines)

func _player_slot_name(player_index: int) -> String:
	if player_index < 0 or player_index >= _player_names.size():
		return "Player %d" % (player_index + 1)
	var entered_name = str(_player_names[player_index]).strip_edges()
	if entered_name == "" or entered_name == ("Player %d" % (player_index + 1)):
		return "Player %d" % (player_index + 1)
	return entered_name

func _name_title_for_player(player_index: int) -> String:
	return NAME_TITLE_VARIANTS[player_index % NAME_TITLE_VARIANTS.size()]

func _name_body_for_player(player_index: int) -> String:
	var template = NAME_BODY_VARIANTS[player_index % NAME_BODY_VARIANTS.size()]
	return template % (player_index + 1)

func _ready_text_for_player(player_index: int) -> String:
	return READY_TEXT_VARIANTS[player_index % READY_TEXT_VARIANTS.size()]

func _display_name_for_heading(player_index: int) -> String:
	if player_index < 0 or player_index >= _player_names.size():
		return "Unknown"
	var entered_name = str(_player_names[player_index]).strip_edges()
	if entered_name == "" or entered_name == ("Player %d" % (player_index + 1)):
		return "Player %d" % (player_index + 1)
	return entered_name

func _role_display_name(role: int) -> String:
	match role:
		Role.CAESAR:
			return "Caesar"
		Role.PATRICIAN:
			return "Patrician Representative"
		_:
			return "Plebeian Representative"
