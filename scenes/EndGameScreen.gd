extends CanvasLayer

## Code-driven end-of-stream stats overlay (layer=55, above WinScreen layer=50).
## Called via show_results(snapshot) by SessionStats 3 s after GAME_OVER.
## Dismissed by any key/click, or automatically after AUTO_HIDE_SEC.

const AUTO_HIDE_SEC := 25.0

const RANK_COLORS: Array[Color] = [
	Color(1.0,  0.85, 0.20, 1.0),   # gold
	Color(0.82, 0.82, 0.88, 1.0),   # silver
	Color(0.78, 0.52, 0.30, 1.0),   # bronze
	Color(0.65, 0.65, 0.65, 0.80),  # 4th
	Color(0.55, 0.55, 0.55, 0.70),  # 5th
]
const TEAM_COLORS: Dictionary = {
	"team_a": Color(0.35, 0.65, 1.0, 1.0),
	"team_b": Color(1.0,  0.40, 0.22, 1.0),
	"":       Color(0.80, 0.80, 0.80, 0.85),
}
const COL_TITLES:   Array[String] = ["TOP DONORS", "TOP KILLERS", "TOP LEVELS"]
const COL_UNITS:    Array[String] = ["pts", "K", "Lv"]
const COL_BORDERS:  Array[Color] = [
	Color(0.3, 0.6,  1.0,  0.7),
	Color(0.5, 0.9,  0.55, 0.6),
	Color(1.0, 0.35, 0.15, 0.65),
]

# Layout
const SEP_X:     float = 80.0
const SEP_W:     float = 1760.0
const COL_W:     float = 540.0
const COL_GAP:   float = 50.0
const COL_X_A:   float = 100.0                    # (1920 - 3*540 - 2*50) / 2 = 100
const COL_X_B:   float = COL_X_A + COL_W + COL_GAP
const COL_X_C:   float = COL_X_B + COL_W + COL_GAP
const ROW_H:     float = 38.0

# ── UI node references ────────────────────────────────────────────────────────
var _root: Control           = null
var _boss_lbl: Label         = null
var _subtitle_lbl: Label     = null
var _col_name_lbls: Array    = [[], [], []]  # [col][row] → Label
var _col_val_lbls: Array     = [[], [], []]
var _ach_bubbles: Array      = []            # Array[Control]
var _ach_bg_list: Array      = []            # Array[ColorRect]
var _ach_lbl_list: Array     = []            # Array[Label]
var _stat_vals: Array[Label] = []
var _next_goal_lbl: Label    = null
var _dismiss_lbl: Label      = null

var _auto_timer: float  = 0.0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	layer = 55
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()

func _process(delta: float) -> void:
	if not visible:
		return
	_auto_timer -= delta
	if _auto_timer <= 0.0:
		dismiss()

# ── Public API ────────────────────────────────────────────────────────────────

func show_results(snap: Dictionary) -> void:
	_populate(snap)
	_root.modulate.a = 0.0
	_root.position.y = 24.0
	show()
	_auto_timer = AUTO_HIDE_SEC
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, 0.55).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_root, "position:y", 0.0, 0.40).set_ease(Tween.EASE_OUT)
	# Pulse the dismiss hint
	var pt := _dismiss_lbl.create_tween().set_loops()
	pt.tween_property(_dismiss_lbl, "modulate:a", 0.25, 0.9)
	pt.tween_property(_dismiss_lbl, "modulate:a", 1.0,  0.9)

func dismiss() -> void:
	if not visible:
		return
	_auto_timer = 0.0
	var tw := _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.40)
	tw.tween_callback(hide)

# ── Data population ───────────────────────────────────────────────────────────

func _populate(snap: Dictionary) -> void:
	var boss: int   = snap.get("highest_boss_cleared", 0)
	var streams: int  = snap.get("total_streams", 1)
	var streak: int   = snap.get("current_streak", 0)
	var next_b: int   = snap.get("next_goal_boss", 1)

	_boss_lbl.text = (
		"Boss Level %d Cleared!" % boss if boss > 0
		else "No Boss Cleared This Stream"
	)
	_subtitle_lbl.text = "Stream #%d   ·   Win Streak: %d" % [streams, streak]

	# Leaderboard columns
	var lists: Array = [
		snap.get("top_donors",  []),
		snap.get("top_killers", []),
		snap.get("top_levels",  []),
	]
	for c: int in 3:
		var rows: Array = lists[c]
		for r: int in 5:
			var nl: Label = _col_name_lbls[c][r]
			var vl: Label = _col_val_lbls[c][r]
			if r < rows.size() and rows[r].get("value", 0) > 0:
				var row: Dictionary = rows[r]
				nl.text = row["player_id"]
				var v: int    = row["value"]
				var unit: String = COL_UNITS[c]
				vl.text = "Lv%d" % v if unit == "Lv" else "%d%s" % [v, unit]
				var tc: Color = TEAM_COLORS.get(row.get("team", ""), TEAM_COLORS[""])
				nl.add_theme_color_override("font_color", tc)
			else:
				nl.text = "---"
				vl.text = "—"
				nl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 0.7))
				vl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.45, 0.7))

	# Achievement bubbles — re-center based on count
	var ach_data: Array = snap.get("achievements", [])
	var count: int = mini(ach_data.size(), 9)
	var bw: float  = 180.0
	var bg: float  = 8.0
	var total_w: float = count * bw + maxi(count - 1, 0) * bg
	var start_x: float = (1920.0 - total_w) / 2.0
	for i: int in 9:
		var bubble: Control = _ach_bubbles[i]
		if i < count:
			var def: Dictionary = ach_data[i]
			var col: Color = def.get("color", Color(0.7, 0.7, 0.7, 1.0))
			(_ach_bg_list[i] as ColorRect).color = Color(col.r * 0.2, col.g * 0.2, col.b * 0.2, 0.9)
			(_ach_lbl_list[i] as Label).text = def.get("label", "???")
			(_ach_lbl_list[i] as Label).add_theme_color_override("font_color", col)
			bubble.position.x = start_x + i * (bw + bg)
			bubble.visible = true
		else:
			bubble.visible = false

	# Stats row
	var stat_data: Array[String] = [
		_fmt_num(snap.get("session_likes", 0)),
		"%d pts" % snap.get("session_donation_pts", 0),
		str(snap.get("total_kills", 0)),
		str(snap.get("total_boss_clears", 0)),
		str(snap.get("current_streak", 0)),
	]
	for i: int in _stat_vals.size():
		_stat_vals[i].text = stat_data[i]

	# Footer
	_next_goal_lbl.text = (
		"Next stream: reach Boss Level %d!" % next_b if boss > 0
		else "Next stream: defeat the Boss!"
	)

# ── UI construction ───────────────────────────────────────────────────────────

func _build() -> void:
	_root = Control.new()
	_root.size = Vector2(1920.0, 1080.0)
	add_child(_root)

	# Background overlay
	var bg := ColorRect.new()
	bg.size  = Vector2(1920.0, 1080.0)
	bg.color = Color(0.02, 0.02, 0.06, 0.90)
	_root.add_child(bg)

	# Gold accent lines
	for yy: float in [0.0, 1078.0]:
		var bar := ColorRect.new()
		bar.position = Vector2(0.0, yy)
		bar.size     = Vector2(1920.0, 2.0)
		bar.color    = Color(1.0, 0.82, 0.18, 0.65)
		_root.add_child(bar)

	_build_header()
	_build_separator(224.0)
	_build_leaderboard(234.0)
	_build_separator(468.0)
	_build_achievements(478.0, 504.0)
	_build_separator(548.0)
	_build_stats_row(560.0)
	_build_footer(638.0)

func _build_header() -> void:
	var title := _make_lbl("STREAM ENDED", 52, Color(0.95, 0.95, 0.95, 1.0))
	title.position = Vector2(0.0, 48.0)
	title.size     = Vector2(1920.0, 62.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 3)
	_root.add_child(title)

	_boss_lbl = _make_lbl("", 28, Color(1.0, 0.85, 0.2, 1.0))
	_boss_lbl.position = Vector2(0.0, 118.0)
	_boss_lbl.size     = Vector2(1920.0, 36.0)
	_boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_lbl.add_theme_constant_override("outline_size", 2)
	_root.add_child(_boss_lbl)

	_subtitle_lbl = _make_lbl("", 15, Color(0.72, 0.88, 1.0, 0.85))
	_subtitle_lbl.position = Vector2(0.0, 162.0)
	_subtitle_lbl.size     = Vector2(1920.0, 20.0)
	_subtitle_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_subtitle_lbl)

func _build_separator(y: float) -> void:
	var sep := ColorRect.new()
	sep.position = Vector2(SEP_X, y)
	sep.size     = Vector2(SEP_W, 2.0)
	sep.color    = Color(1.0, 0.82, 0.18, 0.28)
	_root.add_child(sep)

func _build_leaderboard(y: float) -> void:
	var col_xs: Array[float] = [COL_X_A, COL_X_B, COL_X_C]
	for c: int in 3:
		var cx: float = col_xs[c]

		# Top border
		var border := ColorRect.new()
		border.position = Vector2(cx, y)
		border.size     = Vector2(COL_W, 2.0)
		border.color    = COL_BORDERS[c]
		_root.add_child(border)

		# Title
		var title := _make_lbl(COL_TITLES[c], 12, Color(0.72, 0.88, 1.0, 0.85))
		title.position = Vector2(cx + 6.0, y + 4.0)
		title.size     = Vector2(COL_W - 12.0, 20.0)
		_root.add_child(title)

		# Header separator
		var hsep := ColorRect.new()
		hsep.position = Vector2(cx, y + 26.0)
		hsep.size     = Vector2(COL_W, 1.0)
		hsep.color    = Color(1.0, 1.0, 1.0, 0.08)
		_root.add_child(hsep)

		# 5 data rows
		_col_name_lbls[c] = []
		_col_val_lbls[c]  = []
		for r: int in 5:
			var ry: float = y + 30.0 + r * ROW_H

			# Rank number
			var rank_lbl := _make_lbl("#%d" % (r + 1), 13, RANK_COLORS[r])
			rank_lbl.position = Vector2(cx + 4.0, ry)
			rank_lbl.size     = Vector2(26.0, ROW_H - 2.0)
			rank_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_root.add_child(rank_lbl)

			# Player name
			var name_lbl := _make_lbl("---", 14, Color(0.88, 0.88, 0.88, 0.90))
			name_lbl.position  = Vector2(cx + 34.0, ry)
			name_lbl.size      = Vector2(COL_W - 100.0, ROW_H - 2.0)
			name_lbl.clip_text = true
			name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			_root.add_child(name_lbl)
			_col_name_lbls[c].append(name_lbl)

			# Value
			var val_lbl := _make_lbl("—", 13, RANK_COLORS[r])
			val_lbl.position = Vector2(cx + COL_W - 62.0, ry)
			val_lbl.size     = Vector2(58.0, ROW_H - 2.0)
			val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			val_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			_root.add_child(val_lbl)
			_col_val_lbls[c].append(val_lbl)

func _build_achievements(label_y: float, bubbles_y: float) -> void:
	var header := _make_lbl("ACHIEVEMENTS", 12, Color(0.72, 0.88, 1.0, 0.80))
	header.position = Vector2(SEP_X, label_y)
	header.size     = Vector2(400.0, 20.0)
	_root.add_child(header)

	# Pre-build 9 bubbles; positions are updated in _populate()
	const BW: float = 180.0
	const BH: float = 34.0
	for i: int in 9:
		var c := Control.new()
		c.position = Vector2(0.0, bubbles_y)
		c.size     = Vector2(BW, BH)
		_root.add_child(c)

		var b_bg := ColorRect.new()
		b_bg.size  = Vector2(BW, BH)
		b_bg.color = Color(0.15, 0.15, 0.15, 0.88)
		c.add_child(b_bg)

		var b_border := ColorRect.new()
		b_border.size  = Vector2(BW, 2.0)
		b_border.color = Color(0.6, 0.6, 0.6, 0.8)
		c.add_child(b_border)

		var b_lbl := _make_lbl("", 12, Color(0.85, 0.85, 0.85, 1.0))
		b_lbl.size     = Vector2(BW - 8.0, BH)
		b_lbl.position = Vector2(4.0, 0.0)
		b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		b_lbl.clip_text = true
		c.add_child(b_lbl)

		c.visible = false
		_ach_bubbles.append(c)
		_ach_bg_list.append(b_bg)
		_ach_lbl_list.append(b_lbl)

func _build_stats_row(y: float) -> void:
	const STAT_LABELS: Array[String] = [
		"♥  LIKES", "DONATION PTS", "TOTAL KILLS", "BOSSES CLEARED", "WIN STREAK"
	]
	const STAT_COLORS: Array[Color] = [
		Color(1.0, 0.4, 0.6, 1.0),
		Color(0.35, 0.92, 0.78, 1.0),
		Color(1.0, 0.5, 0.35, 1.0),
		Color(1.0, 0.85, 0.2, 1.0),
		Color(0.5, 0.85, 1.0, 1.0),
	]
	const ITEM_W: float = 320.0
	const ITEM_GAP: float = 12.0
	var total_w: float = 5.0 * ITEM_W + 4.0 * ITEM_GAP
	var start_x: float = (1920.0 - total_w) / 2.0

	for i: int in 5:
		var ix: float = start_x + i * (ITEM_W + ITEM_GAP)

		var bg := ColorRect.new()
		bg.position = Vector2(ix, y)
		bg.size     = Vector2(ITEM_W, 70.0)
		bg.color    = Color(0.0, 0.0, 0.0, 0.50)
		_root.add_child(bg)

		var top_border := ColorRect.new()
		top_border.position = Vector2(ix, y)
		top_border.size     = Vector2(ITEM_W, 2.0)
		top_border.color    = STAT_COLORS[i]
		_root.add_child(top_border)

		var icon_lbl := _make_lbl(STAT_LABELS[i], 11, STAT_COLORS[i])
		icon_lbl.position = Vector2(ix, y + 4.0)
		icon_lbl.size     = Vector2(ITEM_W, 18.0)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_root.add_child(icon_lbl)

		var val_lbl := _make_lbl("0", 30, Color(0.95, 0.95, 0.95, 1.0))
		val_lbl.position = Vector2(ix, y + 24.0)
		val_lbl.size     = Vector2(ITEM_W, 44.0)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		val_lbl.add_theme_constant_override("outline_size", 2)
		_root.add_child(val_lbl)
		_stat_vals.append(val_lbl)

func _build_footer(y: float) -> void:
	_next_goal_lbl = _make_lbl("", 24, Color(1.0, 0.85, 0.2, 1.0))
	_next_goal_lbl.position = Vector2(0.0, y)
	_next_goal_lbl.size     = Vector2(1920.0, 36.0)
	_next_goal_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_next_goal_lbl.add_theme_constant_override("outline_size", 2)
	_root.add_child(_next_goal_lbl)

	var prev_best_lbl := _make_lbl("", 14, Color(0.7, 0.7, 0.7, 0.80))
	prev_best_lbl.name     = "PrevBestLbl"
	prev_best_lbl.position = Vector2(0.0, y + 40.0)
	prev_best_lbl.size     = Vector2(1920.0, 22.0)
	prev_best_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(prev_best_lbl)

	_dismiss_lbl = _make_lbl("[ Press any key or click to dismiss ]", 12, Color(0.65, 0.65, 0.65, 0.85))
	_dismiss_lbl.position = Vector2(0.0, y + 66.0)
	_dismiss_lbl.size     = Vector2(1920.0, 18.0)
	_dismiss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_root.add_child(_dismiss_lbl)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_lbl(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 1)
	return lbl

func _fmt_num(n: int) -> String:
	if n >= 10000:
		return "%dk" % (n / 1000)
	if n >= 1000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)
