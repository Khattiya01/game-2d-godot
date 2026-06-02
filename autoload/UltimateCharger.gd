extends Node

## AutoLoad: tracks per-team ultimate meter (0–100%) and auto-fires at 100%.
## Charge sources wired here; UI bars drawn at top corners of the screen.

const MAX_PCT: float = 100.0
const BAR_W: float   = 360.0
const BAR_H: float   = 18.0
const BAR_Y: float   = 28.0
const TITLE_Y: float = 8.0
const X_A: float     = 12.0
const X_B: float     = 1548.0   # 1920 - 360 - 12

signal ultimate_ready(team: String)
signal meter_updated(team: String, percent: float)

var _meter: Dictionary = { "team_a": 0.0, "team_b": 0.0 }

var _ui_canvas: CanvasLayer = null
var _fill_a: ColorRect      = null
var _fill_b: ColorRect      = null
var _pct_a: Label           = null
var _pct_b: Label           = null
var _ready_a: Label         = null
var _ready_b: Label         = null
var _ready_tween_a: Tween   = null
var _ready_tween_b: Tween   = null
var _was_ready: Dictionary  = { "team_a": false, "team_b": false }

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	UltimateController.ultimate_finished.connect(_on_ultimate_finished)
	BossManager.boss_defeated.connect(_on_boss_defeated)
	ComboTracker.combo_milestone.connect(_on_combo_milestone)
	ComboTracker.combo_sync.connect(_on_combo_sync)

# ── Public API ────────────────────────────────────────────────────────────────

func add_charge(team: String, amount: float) -> void:
	if not _meter.has(team):
		return
	var prev: float = _meter[team]
	_meter[team] = minf(prev + amount, MAX_PCT)
	meter_updated.emit(team, _meter[team])
	_refresh_bar(team)
	if prev < MAX_PCT and _meter[team] >= MAX_PCT:
		_fire_ultimate(team)

# Charges both teams; fires any team that crosses 100%.
func add_charge_both(amount: float) -> void:
	var prev_a: float = _meter["team_a"]
	var prev_b: float = _meter["team_b"]
	_meter["team_a"] = minf(prev_a + amount, MAX_PCT)
	_meter["team_b"] = minf(prev_b + amount, MAX_PCT)
	_refresh_bar("team_a")
	_refresh_bar("team_b")
	meter_updated.emit("team_a", _meter["team_a"])
	meter_updated.emit("team_b", _meter["team_b"])
	if prev_a < MAX_PCT and _meter["team_a"] >= MAX_PCT:
		_fire_ultimate("team_a")
	if prev_b < MAX_PCT and _meter["team_b"] >= MAX_PCT:
		_fire_ultimate("team_b")

# Called after any cinematic finishes; design mandates full reset for both teams.
func reset_meters() -> void:
	_meter["team_a"] = 0.0
	_meter["team_b"] = 0.0
	_refresh_bar("team_a")
	_refresh_bar("team_b")
	meter_updated.emit("team_a", 0.0)
	meter_updated.emit("team_b", 0.0)

func get_percent(team: String) -> float:
	return _meter.get(team, 0.0)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_ultimate_finished(team: String) -> void:
	_meter[team] = 0.0
	_refresh_bar(team)
	meter_updated.emit(team, 0.0)

func _on_boss_defeated(_level: int) -> void:
	add_charge_both(20.0)

func _on_combo_milestone(type: String, _count: int, team: String, _text: String) -> void:
	match type:
		"like_x3":    add_charge(team, 5.0)
		"like_x5":    add_charge(team, 20.0)
		"like_x10":   add_charge_both(50.0)
		"donate_x3":  add_charge(team, 10.0)
		"donate_x10": add_charge(team, 20.0)

func _on_combo_sync(team: String) -> void:
	add_charge(team, 20.0)

# ── Internal ──────────────────────────────────────────────────────────────────

func _fire_ultimate(team: String) -> void:
	_meter[team] = 0.0
	_refresh_bar(team)
	meter_updated.emit(team, 0.0)
	ultimate_ready.emit(team)
	UltimateController.request_ultimate(1 if team == "team_a" else 2)
	print("[UltimateCharger] Ultimate fired  team=%s" % team)

# ── UI build ──────────────────────────────────────────────────────────────────

func _build_ui() -> void:
	_ui_canvas = CanvasLayer.new()
	_ui_canvas.layer = 4   # below dark focus overlay (layer 5) during cinematics
	_ui_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_canvas)
	_build_team_ui("team_a")
	_build_team_ui("team_b")

func _build_team_ui(team: String) -> void:
	var is_a  := team == "team_a"
	var bx    := X_A if is_a else X_B
	var align := HORIZONTAL_ALIGNMENT_LEFT if is_a else HORIZONTAL_ALIGNMENT_RIGHT
	var tcol  := Color(0.4, 0.7, 1.0, 0.85) if is_a else Color(1.0, 0.45, 0.35, 0.85)

	# Title label
	var title := Label.new()
	title.text = "ULTIMATE METER  A" if is_a else "B  ULTIMATE METER"
	title.size = Vector2(BAR_W, 18.0)
	title.position = Vector2(bx, TITLE_Y)
	title.horizontal_alignment = align
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", tcol)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 1)
	_ui_canvas.add_child(title)

	# Bar background
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.10, 0.84)
	bg.size = Vector2(BAR_W, BAR_H)
	bg.position = Vector2(bx, BAR_Y)
	_ui_canvas.add_child(bg)

	# Fill (starts at width 0)
	var fill := ColorRect.new()
	fill.size = Vector2(0.0, BAR_H)
	fill.position = Vector2(bx, BAR_Y)
	_ui_canvas.add_child(fill)

	# Percentage label centred on bar
	var pct := Label.new()
	pct.text = "0%"
	pct.size = Vector2(BAR_W, BAR_H)
	pct.position = Vector2(bx, BAR_Y)
	pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pct.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct.add_theme_font_size_override("font_size", 11)
	pct.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.92))
	pct.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	pct.add_theme_constant_override("outline_size", 1)
	_ui_canvas.add_child(pct)

	# "READY!" label — hidden until 100%
	var rdy := Label.new()
	rdy.text = "READY!"
	rdy.size = Vector2(BAR_W, 20.0)
	rdy.position = Vector2(bx, BAR_Y + BAR_H + 2.0)
	rdy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rdy.add_theme_font_size_override("font_size", 13)
	rdy.add_theme_color_override("font_color", Color(1.0, 1.0, 0.25, 1.0))
	rdy.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	rdy.add_theme_constant_override("outline_size", 2)
	rdy.modulate.a = 0.0
	_ui_canvas.add_child(rdy)

	if is_a:
		_fill_a = fill;  _pct_a = pct;  _ready_a = rdy
	else:
		_fill_b = fill;  _pct_b = pct;  _ready_b = rdy

func _refresh_bar(team: String) -> void:
	var is_a   := team == "team_a"
	var fill   : ColorRect = _fill_a  if is_a else _fill_b
	var pct_l  : Label     = _pct_a   if is_a else _pct_b
	var rdy_l  : Label     = _ready_a if is_a else _ready_b

	if not is_instance_valid(fill):
		return

	var pct: float   = _meter[team]
	var ratio: float = pct / MAX_PCT

	fill.size.x = BAR_W * ratio
	var base  := Color(0.18, 0.48, 1.0) if is_a else Color(1.0, 0.22, 0.18)
	var bright := Color(0.5, 0.82, 1.0) if is_a else Color(1.0, 0.65, 0.5)
	fill.color = base.lerp(bright, ratio)

	if is_instance_valid(pct_l):
		pct_l.text = "%d%%" % int(pct)

	var is_ready: bool = pct >= MAX_PCT
	var was: bool      = _was_ready[team]
	_was_ready[team] = is_ready

	if not is_instance_valid(rdy_l):
		return

	if is_ready and not was:
		# Just hit 100% — start pulse
		rdy_l.modulate.a = 1.0
		var tw := rdy_l.create_tween().set_loops()
		tw.tween_property(rdy_l, "modulate:a", 0.3, 0.45)
		tw.tween_property(rdy_l, "modulate:a", 1.0, 0.45)
		if is_a: _ready_tween_a = tw
		else:    _ready_tween_b = tw
	elif not is_ready and was:
		# Dropped below 100% — stop pulse
		if is_a:
			if _ready_tween_a: _ready_tween_a.kill(); _ready_tween_a = null
		else:
			if _ready_tween_b: _ready_tween_b.kill(); _ready_tween_b = null
		rdy_l.modulate.a = 0.0
