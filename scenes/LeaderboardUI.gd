extends CanvasLayer

## Real-time leaderboard overlay: Top Donors (left), Top Killers (center), Top Levels (right).

const PANEL_W: float = 295.0
const PANEL_H: float = 128.0
const PANEL_Y: float = 942.0
const PANEL_X: Array[float] = [8.0, 812.5, 1617.0]
const TITLES: Array[String] = ["TOP DONORS", "TOP KILLERS", "TOP LEVELS"]

const TOP_COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.2, 1.0),   # gold
	Color(0.82, 0.82, 0.88, 1.0), # silver
	Color(0.78, 0.52, 0.3, 1.0),  # bronze
]
const BORDER_COLORS: Array[Color] = [
	Color(0.3, 0.6, 1.0, 0.7),   # blue for donors panel
	Color(0.5, 0.9, 0.55, 0.6),  # green for killers panel
	Color(1.0, 0.35, 0.15, 0.65), # red for levels panel
]

# Flat arrays: index = panel * 3 + row
var _name_labels: Array[Label] = []
var _val_labels:  Array[Label] = []

func _ready() -> void:
	layer = 3
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	Leaderboard.ranking_changed.connect(_refresh)

func _build_ui() -> void:
	for p in 3:
		_build_panel(p)
	_refresh()

func _build_panel(p: int) -> void:
	var px: float = PANEL_X[p]

	var bg := ColorRect.new()
	bg.position = Vector2(px, PANEL_Y)
	bg.size = Vector2(PANEL_W, PANEL_H)
	bg.color = Color(0.0, 0.0, 0.0, 0.72)
	add_child(bg)

	var border := ColorRect.new()
	border.position = Vector2(px, PANEL_Y)
	border.size = Vector2(PANEL_W, 2.0)
	border.color = BORDER_COLORS[p]
	add_child(border)

	var title := Label.new()
	title.text = TITLES[p]
	title.position = Vector2(px + 8.0, PANEL_Y + 4.0)
	title.size = Vector2(PANEL_W - 16.0, 18.0)
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.85))
	title.add_theme_constant_override("outline_size", 1)
	add_child(title)

	var sep := ColorRect.new()
	sep.position = Vector2(px, PANEL_Y + 24.0)
	sep.size = Vector2(PANEL_W, 1.0)
	sep.color = Color(1.0, 1.0, 1.0, 0.1)
	add_child(sep)

	for r in 3:
		var ry: float = PANEL_Y + 28.0 + r * 32.0

		var rank := Label.new()
		rank.text = "#%d" % (r + 1)
		rank.position = Vector2(px + 5.0, ry)
		rank.size = Vector2(26.0, 28.0)
		rank.add_theme_font_size_override("font_size", 13)
		rank.add_theme_color_override("font_color", TOP_COLORS[r])
		rank.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(rank)

		var name_lbl := Label.new()
		name_lbl.text = "---"
		name_lbl.position = Vector2(px + 33.0, ry)
		name_lbl.size = Vector2(200.0, 28.0)
		name_lbl.add_theme_font_size_override("font_size", 14)
		name_lbl.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92, 0.9))
		name_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
		name_lbl.add_theme_constant_override("outline_size", 1)
		name_lbl.clip_text = true
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(name_lbl)
		_name_labels.append(name_lbl)

		var val_lbl := Label.new()
		val_lbl.text = "-"
		val_lbl.position = Vector2(px + 235.0, ry)
		val_lbl.size = Vector2(57.0, 28.0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		val_lbl.add_theme_font_size_override("font_size", 13)
		val_lbl.add_theme_color_override("font_color", TOP_COLORS[r])
		val_lbl.add_theme_constant_override("outline_size", 1)
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(val_lbl)
		_val_labels.append(val_lbl)

func _refresh() -> void:
	_fill_panel(0, Leaderboard.get_top_donors(3), "pt")
	_fill_panel(1, Leaderboard.get_top_killers(3), "K")
	_fill_panel(2, Leaderboard.get_top_levels(3), "Lv")

func _fill_panel(p: int, rows: Array, unit: String) -> void:
	for r in 3:
		var idx := p * 3 + r
		var name_lbl: Label = _name_labels[idx]
		var val_lbl: Label  = _val_labels[idx]
		if r < rows.size() and (rows[r] as Dictionary)["value"] > 0:
			name_lbl.text = rows[r]["player_id"]
			var v: int = rows[r]["value"]
			val_lbl.text = "Lv%d" % v if unit == "Lv" else "%d%s" % [v, unit]
		else:
			name_lbl.text = "---"
			val_lbl.text  = "-"
