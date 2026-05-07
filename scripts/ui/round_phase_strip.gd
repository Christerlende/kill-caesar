extends HBoxContainer
## Four-step round overview: Curia → Tabulae → Aerarium → Renuntiatio.

const COLOR_GOLD := Color(0.95, 0.82, 0.25, 1)
const COLOR_CREAM := Color(0.95, 0.92, 0.85, 1)
const COLOR_DIM := Color(0.6, 0.55, 0.45, 0.75)
const COLOR_MUTED := Color(0.45, 0.42, 0.38, 0.55)
const COLOR_DONE_BG := Color(0.12, 0.1, 0.08, 0.82)
const COLOR_DONE_BORDER := Color(0.35, 0.32, 0.26, 0.5)
const COLOR_ACTIVE_BG := Color(0.14, 0.11, 0.08, 0.92)
const COLOR_ACTIVE_BORDER := Color(0.72, 0.58, 0.22, 0.9)
const COLOR_FUTURE_BG := Color(0.08, 0.07, 0.06, 0.65)
const COLOR_FUTURE_BORDER := Color(0.28, 0.26, 0.22, 0.45)
const COLOR_CONTEXT := Color(0.78, 0.72, 0.62, 0.95)
const COLOR_CONTEXT_MUTED := Color(0.55, 0.5, 0.44, 0.75)

var _panels: Array = []
var _title_labels: Array = []
var _tag_labels: Array = []
var _context_labels: Array = []

const _PHASES: Array = [
	{"title": "Curia", "tag": "Co-consul ballot"},
	{"title": "Tabulae", "tag": "Strike & read"},
	{"title": "Aerarium", "tag": "Tribute & fate"},
	{"title": "Renuntiatio", "tag": "The Senate's word"},
]

func _ready() -> void:
	alignment = ALIGNMENT_CENTER
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)
	for i in range(4):
		var data: Dictionary = _PHASES[i]
		var col := VBoxContainer.new()
		col.size_flags_horizontal = SIZE_EXPAND_FILL
		col.size_flags_vertical = SIZE_SHRINK_BEGIN
		col.alignment = BoxContainer.ALIGNMENT_BEGIN
		col.add_theme_constant_override("separation", 5)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = SIZE_EXPAND_FILL
		panel.size_flags_vertical = SIZE_SHRINK_BEGIN
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var inner := VBoxContainer.new()
		inner.add_theme_constant_override("separation", 2)
		panel.add_child(inner)
		var title := Label.new()
		title.text = data["title"]
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 14)
		inner.add_child(title)
		var tag := Label.new()
		tag.text = data["tag"]
		tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tag.add_theme_font_size_override("font_size", 11)
		tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inner.add_child(tag)
		col.add_child(panel)
		var ctx := Label.new()
		ctx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ctx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ctx.add_theme_font_size_override("font_size", 11)
		ctx.add_theme_color_override("font_color", COLOR_CONTEXT)
		ctx.size_flags_horizontal = SIZE_EXPAND_FILL
		ctx.visible = false
		ctx.text = ""
		col.add_child(ctx)
		add_child(col)
		_panels.append(panel)
		_title_labels.append(title)
		_tag_labels.append(tag)
		_context_labels.append(ctx)


static func macro_phase_index(state, _game_manager) -> int:
	if state == null:
		return 0
	match state.game_phase:
		"init":
			return 0
		"round_start", "election", "round_end":
			return 0
		"policy":
			return 1
		"spending", "greed":
			return 2
		"result", "award":
			return 3
		"game_over":
			return 3
		_:
			return 0


func sync(state, game_manager, rome_collapse: bool = false, context_line: String = "") -> void:
	if state == null or _panels.is_empty():
		return
	var current: int = macro_phase_index(state, game_manager)
	var trimmed_ctx: String = context_line.strip_edges()
	for i in range(4):
		var is_past: bool = i < current
		var is_current: bool = i == current
		var bg: Color
		var border: Color
		var title_c: Color
		var tag_c: Color
		var bw: int = 1
		if is_current:
			bg = COLOR_ACTIVE_BG
			border = COLOR_ACTIVE_BORDER
			title_c = COLOR_GOLD
			tag_c = COLOR_CREAM
			bw = 2
		elif is_past:
			bg = COLOR_DONE_BG
			border = COLOR_DONE_BORDER
			title_c = COLOR_DIM
			tag_c = Color(COLOR_MUTED.r, COLOR_MUTED.g, COLOR_MUTED.b, 0.72)
		else:
			bg = COLOR_FUTURE_BG
			border = COLOR_FUTURE_BORDER
			title_c = COLOR_MUTED
			tag_c = Color(COLOR_MUTED.r, COLOR_MUTED.g, COLOR_MUTED.b, 0.65)
		var st := StyleBoxFlat.new()
		st.bg_color = bg
		st.set_border_width_all(bw)
		st.border_color = border
		st.corner_radius_top_left = 6
		st.corner_radius_top_right = 6
		st.corner_radius_bottom_left = 6
		st.corner_radius_bottom_right = 6
		st.content_margin_left = 8
		st.content_margin_right = 8
		st.content_margin_top = 6
		st.content_margin_bottom = 6
		_panels[i].add_theme_stylebox_override("panel", st)
		_title_labels[i].add_theme_color_override("font_color", title_c)
		_tag_labels[i].add_theme_color_override("font_color", tag_c)
		var ctx_lbl: Label = _context_labels[i]
		if is_current and trimmed_ctx != "":
			ctx_lbl.text = trimmed_ctx
			ctx_lbl.visible = true
			if rome_collapse:
				ctx_lbl.add_theme_color_override("font_color", COLOR_CONTEXT_MUTED)
			else:
				ctx_lbl.add_theme_color_override("font_color", COLOR_CONTEXT)
		else:
			ctx_lbl.text = ""
			ctx_lbl.visible = false
	if rome_collapse:
		modulate = Color(0.62, 0.6, 0.58, 1)
	else:
		modulate = Color.WHITE
