extends PanelContainer

const Role = preload("res://scripts/data/role.gd").Role

const COLOR_GOLD = Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM = Color(0.95, 0.92, 0.85, 1)
const COLOR_DARK_RED = Color(0.4, 0.08, 0.08, 1)
const COLOR_RED_BORDER = Color(0.8, 0.1, 0.1, 1)
const COLOR_WHITE = Color(1, 1, 1, 0.95)

var game_manager = null
var viewing_player_id: int = -1  # Which player is viewing this panel

var _assassination_counter_container: VBoxContainer
var _token_squares: Array = []  # Array of 3 AssassinationTokenSquare nodes
var _your_tokens_section: VBoxContainer
var _place_button: Button
var _counter_label: Label
var _rounds_left_label: Label

func _ready() -> void:
	clip_contents = true
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.06, 0.04, 0.95)
	add_theme_stylebox_override("panel", style)
	
	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	
	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)
	
	# ─── Assassination Counter Section ───
	_assassination_counter_container = VBoxContainer.new()
	_assassination_counter_container.add_theme_constant_override("separation", 8)
	vbox.add_child(_assassination_counter_container)
	
	var counter_title = Label.new()
	counter_title.text = "Assassination Counter"
	counter_title.add_theme_font_size_override("font_size", 18)
	counter_title.add_theme_color_override("font_color", COLOR_GOLD)
	counter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_assassination_counter_container.add_child(counter_title)
	
	var squares_hbox = HBoxContainer.new()
	squares_hbox.add_theme_constant_override("separation", 6)
	squares_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_assassination_counter_container.add_child(squares_hbox)
	
	# Create 3 assassination token squares
	for i in range(3):
		var square = _create_assassination_square()
		_token_squares.append(square)
		squares_hbox.add_child(square)
	
	vbox.add_child(HSeparator.new())
	
	# ─── Your Assassination Tokens Section ───
	_your_tokens_section = VBoxContainer.new()
	_your_tokens_section.add_theme_constant_override("separation", 6)
	vbox.add_child(_your_tokens_section)
	
	var your_tokens_title = Label.new()
	your_tokens_title.text = "Your Assassination Tokens"
	your_tokens_title.add_theme_font_size_override("font_size", 14)
	your_tokens_title.add_theme_color_override("font_color", COLOR_CREAM)
	your_tokens_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_your_tokens_section.add_child(your_tokens_title)
	
	var token_info_hbox = HBoxContainer.new()
	token_info_hbox.add_theme_constant_override("separation", 8)
	token_info_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_your_tokens_section.add_child(token_info_hbox)
	
	# Knife icon or empty space
	var knife_label = Label.new()
	knife_label.text = "🔪"
	knife_label.add_theme_font_size_override("font_size", 20)
	knife_label.custom_minimum_size = Vector2(30, 24)
	token_info_hbox.add_child(knife_label)
	
	# Counter "0/1" or "1/1"
	_counter_label = Label.new()
	_counter_label.text = "0/1"
	_counter_label.add_theme_font_size_override("font_size", 16)
	_counter_label.add_theme_color_override("font_color", COLOR_CREAM)
	token_info_hbox.add_child(_counter_label)
	
	# Place button
	_place_button = Button.new()
	_place_button.text = "Place"
	_place_button.disabled = true
	_place_button.pressed.connect(_on_place_token_pressed)
	_place_button.add_theme_font_size_override("font_size", 12)
	_place_button.add_theme_color_override("font_color", COLOR_CREAM)
	token_info_hbox.add_child(_place_button)
	
	# Rounds left label
	_rounds_left_label = Label.new()
	_rounds_left_label.text = ""
	_rounds_left_label.add_theme_font_size_override("font_size", 10)
	_rounds_left_label.add_theme_color_override("font_color", COLOR_CREAM)
	_rounds_left_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_your_tokens_section.add_child(_rounds_left_label)

func _create_assassination_square() -> PanelContainer:
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(32, 32)
	
	var style = StyleBoxFlat.new()
	style.bg_color = COLOR_DARK_RED
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_RED_BORDER
	panel.add_theme_stylebox_override("panel", style)
	
	var cross_label = Label.new()
	cross_label.text = ""  # Empty by default, will be "✕" if crossed
	cross_label.add_theme_font_size_override("font_size", 20)
	cross_label.add_theme_color_override("font_color", COLOR_WHITE)
	cross_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cross_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	panel.add_child(cross_label)
	
	# Store reference to the label for updates
	panel.set_meta("cross_label", cross_label)
	
	return panel

func _process(_delta: float) -> void:
	if not game_manager or viewing_player_id < 0:
		return

	var state = game_manager.state
	var viewer = state.players[viewing_player_id]
	
	# Update assassination counter display (tokens on THIS player)
	var tokens_on_me = _visible_tokens_on_player(viewing_player_id, state.game_phase)
	for i in range(3):
		var cross = _token_squares[i].get_meta("cross_label")
		if i < tokens_on_me.size():
			cross.text = "✕"
		else:
			cross.text = ""
	
	# Update your tokens section
	var my_tokens = viewer.available_assassination_tokens
	_counter_label.text = "%d/1" % my_tokens
	_place_button.disabled = my_tokens == 0 or viewer.is_dead or state.game_phase == "result"
	
	# Show rounds left if player has a token waiting to be placed
	if viewer.is_dead:
		_rounds_left_label.text = "You are dead"
	elif my_tokens > 0:
		_rounds_left_label.text = "Ready to place"
	else:
		_rounds_left_label.text = ""

func _on_place_token_pressed() -> void:
	if viewing_player_id < 0:
		return
	var state = game_manager.state
	var viewer = state.players[viewing_player_id]
	if state.game_phase == "result" or viewer.is_dead or viewer.available_assassination_tokens < 1:
		return
	
	# Create and show the target selection dialog
	var dialog = _create_target_selection_dialog()
	get_tree().root.add_child(dialog)
	_show_target_selection_dialog(dialog)

func _create_target_selection_dialog() -> Popup:
	var popup = Popup.new()
	popup.transparent_bg = true
	popup.set_meta("selected_target_id", -1)

	var panel = PanelContainer.new()
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.28, 0.06, 0.06, 0.98)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = COLOR_GOLD
	panel_style.corner_radius_top_left = 8
	panel_style.corner_radius_top_right = 8
	panel_style.corner_radius_bottom_left = 8
	panel_style.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", panel_style)
	popup.add_child(panel)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var instructions = Label.new()
	instructions.text = "Choose a target:"
	instructions.add_theme_font_size_override("font_size", 12)
	instructions.add_theme_color_override("font_color", COLOR_CREAM)
	popup.set_meta("instructions_label", instructions)
	vbox.add_child(instructions)

	var list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	popup.set_meta("targets_list", list)
	vbox.add_child(list)

	# Create a button for each living opponent
	var target_count = 0
	for player_id in range(game_manager.state.players.size()):
		if player_id == viewing_player_id:
			continue
		var player = game_manager.state.players[player_id]
		if player.is_dead:
			continue
		var btn = Button.new()
		btn.text = game_manager.get_player_name(player_id)
		btn.toggle_mode = true
		btn.custom_minimum_size = Vector2(0, 28)
		btn.set_meta("target_player_id", player_id)
		btn.pressed.connect(_on_target_selected.bind(player_id, popup))
		list.add_child(btn)
		target_count += 1

	var button_row = HBoxContainer.new()
	button_row.add_theme_constant_override("separation", 8)
	button_row.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_child(button_row)

	var cancel_btn = Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.pressed.connect(popup.hide)
	button_row.add_child(cancel_btn)

	var confirm_btn = Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.disabled = true
	confirm_btn.pressed.connect(_on_target_confirmed.bind(popup))
	button_row.add_child(confirm_btn)
	popup.set_meta("confirm_button", confirm_btn)

	# Size naturally to content (no scroll)
	var content_height = 84 + target_count * 32
	popup.size = Vector2(260, content_height)

	popup.popup_hide.connect(popup.queue_free)

	return popup

func _show_target_selection_dialog(dialog: Popup) -> void:
	var viewport_size = get_viewport_rect().size
	var desired_size = dialog.size
	# Right-align with this panel; bottom sits just above the Place button
	var popup_x = int(global_position.x + size.x - desired_size.x)
	var popup_y = int(_place_button.global_position.y - desired_size.y - 4)
	popup_x = clamp(popup_x, 0, int(viewport_size.x - desired_size.x))
	popup_y = clamp(popup_y, 0, int(viewport_size.y - desired_size.y))
	dialog.popup(Rect2i(Vector2i(popup_x, popup_y), Vector2i(int(desired_size.x), int(desired_size.y))))

func _visible_tokens_on_player(target_id: int, current_phase: String) -> Array:
	var visible_tokens = []
	for token in game_manager.get_tokens_on_player(target_id):
		if current_phase in ["election", "policy", "spending"] and token.placed_this_round:
			continue
		visible_tokens.append(token)
	return visible_tokens

func _on_target_selected(target_id: int, popup: Popup) -> void:
	popup.set_meta("selected_target_id", target_id)
	var list = popup.get_meta("targets_list") as VBoxContainer
	if list:
		for child in list.get_children():
			if child is Button:
				var btn = child as Button
				btn.button_pressed = false
				# Reset to default style
				btn.remove_theme_stylebox_override("normal")
				btn.remove_theme_stylebox_override("pressed")
				if btn.has_meta("target_player_id") and int(btn.get_meta("target_player_id")) == target_id:
					btn.button_pressed = true
					var highlight = StyleBoxFlat.new()
					highlight.bg_color = Color(0.35, 0.1, 0.1, 1.0)
					highlight.border_width_left = 2
					highlight.border_width_top = 2
					highlight.border_width_right = 2
					highlight.border_width_bottom = 2
					highlight.border_color = COLOR_GOLD
					highlight.corner_radius_top_left = 4
					highlight.corner_radius_top_right = 4
					highlight.corner_radius_bottom_left = 4
					highlight.corner_radius_bottom_right = 4
					btn.add_theme_stylebox_override("normal", highlight)
					btn.add_theme_stylebox_override("pressed", highlight)
	(popup.get_meta("confirm_button") as Button).disabled = false

func _on_target_confirmed(popup: Popup) -> void:
	var selected_target = int(popup.get_meta("selected_target_id"))
	if selected_target < 0:
		return
	popup.hide()
	if game_manager.place_assassination_token(viewing_player_id, selected_target):
		_show_assassination_sent_message()

func _show_assassination_sent_message() -> void:
	# Create a temporary label that appears and fades out
	var msg_label = Label.new()
	msg_label.text = "The assassin has been sent..."
	msg_label.add_theme_font_size_override("font_size", 16)
	msg_label.add_theme_color_override("font_color", COLOR_RED_BORDER)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	add_child(msg_label)
	
	# Fade in, hold, fade out
	var tween = create_tween()
	msg_label.modulate = Color(1, 1, 1, 0)
	tween.tween_property(msg_label, "modulate:a", 1.0, 0.3)
	tween.tween_interval(1.5)
	tween.tween_property(msg_label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(msg_label.queue_free)

func set_viewing_player(player_id: int) -> void:
	viewing_player_id = player_id
