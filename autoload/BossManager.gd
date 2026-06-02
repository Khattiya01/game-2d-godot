extends Node

enum BossState { IDLE, ANNOUNCING, ACTIVE, RESOLVED }

# ── Duel phase pacing ─────────────────────────────────────────────────────────
# Duel interval scales with upcoming boss level so players have time to farm.
# Lv1 → 3 min, +30 s per level, capped at 5 min.
const DUEL_INTERVAL_BASE: float  = 180.0   # 3 min at Lv1
const DUEL_INTERVAL_STEP: float  = 30.0    # +30 s per level
const DUEL_INTERVAL_MAX: float   = 300.0   # hard cap at 5 min (Lv5+)

# ── Close-match early trigger ─────────────────────────────────────────────────
const CLOSE_MATCH_GAP: int        = 20     # score gap that triggers early spawn
const CLOSE_MATCH_MIN_RATIO: float = 0.35  # must wait ≥ 35% of duel interval first

const ANNOUNCE_DURATION: float = 10.0

# ── State ─────────────────────────────────────────────────────────────────────
var current_boss_level: int = 1
var state: BossState = BossState.IDLE
var _arena_ref: Node = null
var _boss_node: Node = null
var _auto_timer: float = 0.0
var _duel_interval: float = DUEL_INTERVAL_BASE  # recalculated after each boss phase
var _last_duel_second: int = -1

# ── Signals ───────────────────────────────────────────────────────────────────
signal boss_phase_started(level: int)
signal boss_defeated(level: int)
signal boss_failed(level: int)
signal duel_phase_started(interval_secs: float)

# ── Countdown UI (CanvasLayer layer=3) ───────────────────────────────────────
const _CD_X: float = 820.0   # center strip (1920/2 - 280/2 = 820)
const _CD_Y: float = 74.0    # just below UltimateMeter READY! label
const _CD_W: float = 280.0
const _CD_H: float = 22.0
const _BAR_W: float = 110.0
const _BAR_X_OFF: float = 88.0  # offset from _CD_X to bar start

var _canvas: CanvasLayer     = null
var _bar_bg: ColorRect       = null
var _bar_fill: ColorRect     = null
var _boss_lv_lbl: Label      = null
var _time_lbl: Label         = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_countdown_ui()

func register_arena(arena: Node) -> void:
	_arena_ref = arena

# ── Pacing formula ────────────────────────────────────────────────────────────

func get_duel_interval(boss_level: int) -> float:
	return clampf(
		DUEL_INTERVAL_BASE + float(boss_level - 1) * DUEL_INTERVAL_STEP,
		DUEL_INTERVAL_BASE, DUEL_INTERVAL_MAX
	)

# ── Main loop ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if state != BossState.IDLE:
		_last_duel_second = -1
		_set_ui_visible(false)
		return

	if not is_instance_valid(_arena_ref) or not _arena_ref.game_active:
		_auto_timer = 0.0
		_last_duel_second = -1
		_set_ui_visible(false)
		return

	_auto_timer += delta
	_set_ui_visible(true)

	# Throttled per-second countdown refresh
	var time_left: float = maxf(0.0, _duel_interval - _auto_timer)
	var cur_sec: int = int(time_left)
	if cur_sec != _last_duel_second:
		_last_duel_second = cur_sec
		_refresh_countdown(time_left)

	if _auto_timer >= _duel_interval:
		_auto_timer = 0.0
		request_spawn()
		return

	# Close-match early trigger — only after min wait ratio of current interval
	var close_min: float = _duel_interval * CLOSE_MATCH_MIN_RATIO
	if _auto_timer >= close_min:
		var gap: int = abs(_arena_ref.score_a - _arena_ref.score_b)
		if gap <= CLOSE_MATCH_GAP:
			_auto_timer = 0.0
			request_spawn()

func request_spawn() -> void:
	if state != BossState.IDLE:
		return
	if not is_instance_valid(_arena_ref):
		push_warning("[BossManager] No arena registered")
		return
	_announce_and_spawn()

func _announce_and_spawn() -> void:
	state = BossState.ANNOUNCING
	_arena_ref.start_boss_announce(current_boss_level)
	await get_tree().create_timer(ANNOUNCE_DURATION).timeout
	if state != BossState.ANNOUNCING:
		return
	_do_spawn()

func _do_spawn() -> void:
	state = BossState.ACTIVE
	_arena_ref.enter_boss_phase()
	var BossScene: PackedScene = load("res://scenes/Boss.tscn")
	_boss_node = BossScene.instantiate()
	_arena_ref.game_layer.add_child(_boss_node)
	_boss_node.setup(current_boss_level, _arena_ref)
	_boss_node.boss_defeated.connect(_on_boss_defeated)
	_boss_node.boss_timed_out.connect(_on_boss_timed_out)
	_arena_ref.register_boss(_boss_node)
	boss_phase_started.emit(current_boss_level)
	print("[BossManager] Boss Lv%d active  HP=%d  DMG=%d  TIME=%ds" % [
		current_boss_level,
		get_boss_hp(current_boss_level),
		get_boss_dmg(current_boss_level),
		int(get_boss_time(current_boss_level))
	])

func _on_boss_defeated() -> void:
	if state != BossState.ACTIVE:
		return
	state = BossState.RESOLVED
	var level := current_boss_level
	_boss_node = null
	current_boss_level += 1
	_duel_interval = get_duel_interval(current_boss_level)
	_auto_timer = 0.0
	_update_boss_lv_label()
	PlayerStats.on_boss_cleared(level)
	boss_defeated.emit(level)
	_arena_ref.exit_boss_phase(true, level)
	print("[BossManager] Next duel  Lv%d  interval=%.0fs" % [current_boss_level, _duel_interval])
	await get_tree().create_timer(3.0).timeout
	state = BossState.IDLE
	duel_phase_started.emit(_duel_interval)

func _on_boss_timed_out() -> void:
	if state != BossState.ACTIVE:
		return
	state = BossState.RESOLVED
	var level := current_boss_level
	_boss_node = null
	_duel_interval = get_duel_interval(current_boss_level)
	_auto_timer = 0.0
	boss_failed.emit(level)
	_arena_ref.exit_boss_phase(false, level)
	print("[BossManager] Boss Lv%d failed — retry. Duel: %.0fs" % [level, _duel_interval])
	await get_tree().create_timer(2.0).timeout
	state = BossState.IDLE
	duel_phase_started.emit(_duel_interval)

# ── Stat formulas ─────────────────────────────────────────────────────────────

func get_boss_hp(level: int) -> int:
	return int(100.0 * pow(1.6, float(level)))

func get_boss_dmg(level: int) -> int:
	# Mirrors player HP formula (100 + lv^1.8 × 50) ÷ 2 so boss stays proportionally lethal at every level
	return int(50.0 + pow(float(level), 1.8) * 25.0)

func get_boss_time(level: int) -> float:
	return 120.0 + float(level) * 10.0

# ── Countdown UI ──────────────────────────────────────────────────────────────

func _build_countdown_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 3
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	var bg := ColorRect.new()
	bg.position = Vector2(_CD_X, _CD_Y)
	bg.size     = Vector2(_CD_W, _CD_H)
	bg.color    = Color(0.0, 0.0, 0.0, 0.55)
	_canvas.add_child(bg)

	# "BOSS Lv.X" label on left
	_boss_lv_lbl = _make_lbl("BOSS  Lv.1", 11, Color(1.0, 0.45, 0.25, 0.9))
	_boss_lv_lbl.position = Vector2(_CD_X + 4.0, _CD_Y)
	_boss_lv_lbl.size     = Vector2(82.0, _CD_H)
	_boss_lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_canvas.add_child(_boss_lv_lbl)

	# Progress bar background (center)
	_bar_bg = ColorRect.new()
	_bar_bg.position = Vector2(_CD_X + _BAR_X_OFF, _CD_Y + 7.0)
	_bar_bg.size     = Vector2(_BAR_W, 8.0)
	_bar_bg.color    = Color(0.08, 0.08, 0.14, 0.9)
	_canvas.add_child(_bar_bg)

	# Progress bar fill — drains as timer counts up
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(_CD_X + _BAR_X_OFF, _CD_Y + 7.0)
	_bar_fill.size     = Vector2(_BAR_W, 8.0)
	_bar_fill.color    = Color(0.3, 0.85, 0.4, 0.85)
	_canvas.add_child(_bar_fill)

	# "M:SS" countdown label on right
	_time_lbl = _make_lbl("3:00", 13, Color(1.0, 0.85, 0.3, 1.0))
	_time_lbl.position = Vector2(_CD_X + _BAR_X_OFF + _BAR_W + 6.0, _CD_Y)
	_time_lbl.size     = Vector2(72.0, _CD_H)
	_time_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_time_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_time_lbl.add_theme_constant_override("outline_size", 1)
	_canvas.add_child(_time_lbl)

	_set_ui_visible(false)

func _refresh_countdown(time_left: float) -> void:
	if not is_instance_valid(_time_lbl):
		return
	var m: int = int(time_left) / 60
	var s: int = int(time_left) % 60
	_time_lbl.text = "%d:%02d" % [m, s]

	# Bar drains from full to empty as duel time passes
	var ratio: float = time_left / _duel_interval
	_bar_fill.size.x = _BAR_W * ratio

	# Color: green → yellow → red as boss approaches
	var col: Color
	if ratio > 0.5:
		col = Color(0.3, 0.85, 0.4, 0.85)
	elif ratio > 0.25:
		col = Color(0.92, 0.78, 0.12, 0.85)
	else:
		col = Color(1.0, 0.28, 0.12, 0.9)
	_bar_fill.color = col

func _set_ui_visible(v: bool) -> void:
	if is_instance_valid(_canvas):
		_canvas.visible = v

func _update_boss_lv_label() -> void:
	if is_instance_valid(_boss_lv_lbl):
		_boss_lv_lbl.text = "BOSS  Lv.%d" % current_boss_level

func _make_lbl(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 1)
	return lbl
