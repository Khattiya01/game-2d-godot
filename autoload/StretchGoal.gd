extends Node

## AutoLoad: stretch-goal tier system.
## Tracks donation pts, unlocks tiers with gameplay effects, and draws a
## large progress-bar UI (CanvasLayer layer=2) on the right side of the screen.

signal goal_progress_updated(total_pts: int, next_pts: int)
signal goal_tier_unlocked(tier_idx: int, tier_data: Dictionary)

# ── Tier definitions ──────────────────────────────────────────────────────────
# effect_id drives _apply_effect(); label shown in UI; pts = cumulative threshold.
const TIERS: Array[Dictionary] = [
	{ "pts": 50,   "label": "Extra Visual Effects", "effect": "atk_boost_small",  "desc": "All attacks  +20%  for 60s!"         },
	{ "pts": 100,  "label": "Boss Rush!",            "effect": "boss_rush",        "desc": "A Boss appears early!"                },
	{ "pts": 200,  "label": "Dragon Awakening",      "effect": "dragon_awakening", "desc": "+200 HP  &  +50% ATK  for 45s!"       },
	{ "pts": 500,  "label": "Legendary Mode",        "effect": "legendary_mode",   "desc": "+100% ATK  &  +500 HP — LEGENDARY!"   },
	{ "pts": 1000, "label": "ULTIMATE EVENT!",       "effect": "ultimate_event",   "desc": "DOUBLE ULTIMATE UNLEASHED!"           },
]

# ── Layout ────────────────────────────────────────────────────────────────────
const PANEL_X: float  = 1548.0
const PANEL_Y: float  = 282.0
const PANEL_W: float  = 360.0

const TIER_CELL_W: float = 56.0
const TIER_CELL_H: float = 36.0
const BAR_H: float       = 20.0

# Tier cell positions within the panel (5 cells, evenly spaced inside PANEL_W).
const _TIER_OFFSETS: Array[float] = [0.0, 76.0, 152.0, 228.0, 304.0]

# ── State ─────────────────────────────────────────────────────────────────────
var total_pts: int      = 0
var _next_tier_idx: int = 0
var _arena_ref: Node    = null

# ── UI references ─────────────────────────────────────────────────────────────
var _canvas: CanvasLayer        = null
var _pts_lbl: Label             = null
var _bar_fill: ColorRect        = null
var _bar_text: Label            = null
var _next_lbl: Label            = null
var _count_lbl: Label           = null
var _tier_cells: Array[Control] = []   # one per tier
var _tier_bg_list: Array[ColorRect] = []
var _tier_lbl_list: Array[Label]    = []

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GameManager.trigger_effect_requested.connect(_on_gift_effect)
	GameManager.game_state_changed.connect(_on_state_changed)

func register_arena(arena: Node) -> void:
	_arena_ref = arena

# ── Public ────────────────────────────────────────────────────────────────────

func reset() -> void:
	total_pts      = 0
	_next_tier_idx = 0
	_refresh_ui()

func get_next_tier_pts() -> int:
	if _next_tier_idx < TIERS.size():
		return TIERS[_next_tier_idx]["pts"]
	return TIERS[TIERS.size() - 1]["pts"]

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_gift_effect(data: Dictionary) -> void:
	var tier := str(data.get("tier", ""))
	if tier == "micro" or tier.is_empty():
		return
	var gift := str(data.get("gift", ""))
	var pts: int = GameManager.GIFT_TABLE.get(gift, {}).get("score", 0)
	if pts <= 0:
		return
	total_pts += pts
	goal_progress_updated.emit(total_pts, get_next_tier_pts())
	_refresh_ui()
	# Check if any new tiers unlock.
	while _next_tier_idx < TIERS.size():
		var threshold: int = TIERS[_next_tier_idx]["pts"]
		if total_pts >= threshold:
			_unlock_tier(_next_tier_idx)
			_next_tier_idx += 1
		else:
			break

func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.WAITING:
		reset()

# ── Tier unlock ───────────────────────────────────────────────────────────────

func _unlock_tier(idx: int) -> void:
	var t: Dictionary = TIERS[idx]
	print("[StretchGoal] Tier %d unlocked: %s  (effect=%s)" % [idx + 1, t["label"], t["effect"]])
	goal_tier_unlocked.emit(idx, t)
	_apply_effect(t["effect"])
	_show_unlock_announcement(t["label"], t["desc"], idx)
	_refresh_ui()

func _apply_effect(effect_id: String) -> void:
	var arena_ok := is_instance_valid(_arena_ref)
	match effect_id:
		"atk_boost_small":
			if arena_ok:
				_arena_ref.apply_damage_buff(1, 1.2, 60.0)
				_arena_ref.apply_damage_buff(2, 1.2, 60.0)

		"boss_rush":
			if BossManager.state == BossManager.BossState.IDLE:
				BossManager.request_spawn()

		"dragon_awakening":
			if arena_ok:
				_arena_ref.heal_team(1, 200)
				_arena_ref.heal_team(2, 200)
				_arena_ref.apply_damage_buff(1, 1.5, 45.0)
				_arena_ref.apply_damage_buff(2, 1.5, 45.0)

		"legendary_mode":
			if arena_ok:
				_arena_ref.heal_team(1, 500)
				_arena_ref.heal_team(2, 500)
				_arena_ref.apply_damage_buff(1, 2.0, 90.0)
				_arena_ref.apply_damage_buff(2, 2.0, 90.0)

		"ultimate_event":
			UltimateController.request_ultimate(1)
			UltimateController.request_ultimate(2)

# ── Unlock announcement overlay ───────────────────────────────────────────────

func _show_unlock_announcement(title: String, desc: String, tier_idx: int) -> void:
	var overlay := CanvasLayer.new()
	overlay.layer = 14
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(overlay)

	var tier_cols: Array[Color] = [
		Color(0.35, 0.92, 0.78, 1.0),   # teal  (tier 1)
		Color(1.0,  0.40, 0.22, 1.0),   # red   (boss rush)
		Color(0.6,  0.40, 1.0,  1.0),   # purple (dragon)
		Color(1.0,  0.85, 0.20, 1.0),   # gold  (legendary)
		Color(1.0,  0.55, 0.15, 1.0),   # orange (ultimate)
	]
	var col: Color = tier_cols[clampi(tier_idx, 0, tier_cols.size() - 1)]

	# Flash backdrop
	var flash := ColorRect.new()
	flash.size  = Vector2(1920.0, 1080.0)
	flash.color = Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 0.0)
	overlay.add_child(flash)

	# Panel background
	var panel := Control.new()
	panel.position = Vector2(560.0, -120.0)
	panel.size     = Vector2(800.0, 120.0)
	overlay.add_child(panel)

	var pbg := ColorRect.new()
	pbg.size  = Vector2(800.0, 120.0)
	pbg.color = Color(0.0, 0.0, 0.0, 0.82)
	panel.add_child(pbg)

	var top_bar := ColorRect.new()
	top_bar.size  = Vector2(800.0, 3.0)
	top_bar.color = col
	panel.add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.position = Vector2(0.0, 117.0)
	bot_bar.size     = Vector2(800.0, 3.0)
	bot_bar.color    = col
	panel.add_child(bot_bar)

	var tier_lbl := _make_lbl("TIER %d UNLOCKED!" % (tier_idx + 1), 15, col)
	tier_lbl.position = Vector2(8.0, 6.0)
	tier_lbl.size     = Vector2(784.0, 22.0)
	tier_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(tier_lbl)

	var title_lbl := _make_lbl(title, 38, col)
	title_lbl.position = Vector2(8.0, 30.0)
	title_lbl.size     = Vector2(784.0, 46.0)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_constant_override("outline_size", 3)
	panel.add_child(title_lbl)

	var desc_lbl := _make_lbl(desc, 16, Color(0.88, 0.88, 0.88, 0.95))
	desc_lbl.position = Vector2(8.0, 80.0)
	desc_lbl.size     = Vector2(784.0, 26.0)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(desc_lbl)

	# Animate: flash in, slide panel down, hold, slide out
	var tw := overlay.create_tween()
	tw.tween_property(flash, "color:a", 0.35, 0.12)
	tw.parallel().tween_property(panel, "position:y", 240.0, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_interval(2.6)
	tw.tween_property(flash, "color:a", 0.0, 0.4)
	tw.parallel().tween_property(panel, "position:y", -120.0, 0.28).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tw.tween_callback(overlay.queue_free)

# ── UI refresh ────────────────────────────────────────────────────────────────

func _refresh_ui() -> void:
	if not is_instance_valid(_pts_lbl):
		return

	var unlocked: int = _next_tier_idx
	var is_maxed: bool = unlocked >= TIERS.size()

	# Points label
	_pts_lbl.text = "%d pts" % total_pts

	# Tier cells
	for i: int in TIERS.size():
		var bg: ColorRect = _tier_bg_list[i]
		var lbl: Label    = _tier_lbl_list[i]
		if i < unlocked:
			bg.color  = Color(0.15, 0.55, 0.25, 0.85)
			lbl.text  = "✓"
			lbl.add_theme_font_size_override("font_size", 16)
			lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55, 1.0))
		elif i == unlocked and not is_maxed:
			bg.color  = Color(0.16, 0.16, 0.20, 0.9)
			lbl.text  = "%dpts" % TIERS[i]["pts"]
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
		else:
			bg.color  = Color(0.08, 0.08, 0.10, 0.88)
			lbl.text  = "%dpts" % TIERS[i]["pts"]
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5, 0.7))

	# Progress bar
	if is_maxed:
		_bar_fill.size.x = PANEL_W
		_bar_fill.color  = Color(1.0, 0.85, 0.2, 0.9)
		_bar_text.text   = "ALL GOALS CLEARED!"
		_next_lbl.text   = "Maximum reached — amazing stream!"
		_count_lbl.text  = "5 / 5 TIERS UNLOCKED"
	else:
		var prev_pts: int  = TIERS[unlocked - 1]["pts"] if unlocked > 0 else 0
		var next_pts: int  = TIERS[unlocked]["pts"]
		var range_pts: int = next_pts - prev_pts
		var done_pts: int  = total_pts - prev_pts
		var ratio: float   = clampf(float(done_pts) / float(range_pts), 0.0, 1.0)
		_bar_fill.size.x = PANEL_W * ratio
		var base  := Color(0.22, 0.50, 0.92, 0.88)
		var peak  := Color(1.0,  0.85, 0.20, 0.95)
		_bar_fill.color  = base.lerp(peak, ratio)
		_bar_text.text   = "%d / %d pts" % [total_pts, next_pts]
		_next_lbl.text   = "► %s" % TIERS[unlocked]["label"]
		_count_lbl.text  = "%d / 5 TIERS UNLOCKED" % unlocked

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 2
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	var px: float = PANEL_X
	var py: float = PANEL_Y
	var pw: float = PANEL_W

	# Dark background
	var bg := ColorRect.new()
	bg.position = Vector2(px, py)
	bg.size     = Vector2(pw, 132.0)
	bg.color    = Color(0.0, 0.0, 0.0, 0.58)
	_canvas.add_child(bg)

	# Gold top border
	var top := ColorRect.new()
	top.position = Vector2(px, py)
	top.size     = Vector2(pw, 2.0)
	top.color    = Color(1.0, 0.82, 0.18, 0.55)
	_canvas.add_child(top)

	# "STREAM GOALS" title
	var title := _make_lbl("STREAM GOALS", 11, Color(0.72, 0.88, 1.0, 0.85))
	title.position = Vector2(px + 6.0, py + 4.0)
	title.size     = Vector2(200.0, 18.0)
	_canvas.add_child(title)

	# Points counter (right-aligned on title row)
	_pts_lbl = _make_lbl("0 pts", 13, Color(1.0, 0.85, 0.2, 1.0))
	_pts_lbl.position = Vector2(px, py + 4.0)
	_pts_lbl.size     = Vector2(pw - 6.0, 18.0)
	_pts_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_pts_lbl.add_theme_constant_override("outline_size", 1)
	_canvas.add_child(_pts_lbl)

	# 5 Tier cells
	for i: int in TIERS.size():
		var cx: float = px + _TIER_OFFSETS[i]
		var cy: float = py + 26.0

		var cell := Control.new()
		cell.position = Vector2(cx, cy)
		cell.size     = Vector2(TIER_CELL_W, TIER_CELL_H)
		_canvas.add_child(cell)

		var cell_bg := ColorRect.new()
		cell_bg.size  = Vector2(TIER_CELL_W, TIER_CELL_H)
		cell_bg.color = Color(0.08, 0.08, 0.10, 0.88)
		cell.add_child(cell_bg)

		var cell_lbl := _make_lbl("%dpts" % TIERS[i]["pts"], 9, Color(0.5, 0.5, 0.5, 0.7))
		cell_lbl.size = Vector2(TIER_CELL_W, TIER_CELL_H)
		cell_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		cell.add_child(cell_lbl)

		_tier_cells.append(cell)
		_tier_bg_list.append(cell_bg)
		_tier_lbl_list.append(cell_lbl)

	# Progress bar background
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(px, py + 68.0)
	bar_bg.size     = Vector2(pw, BAR_H)
	bar_bg.color    = Color(0.06, 0.06, 0.12, 0.92)
	_canvas.add_child(bar_bg)

	# Progress bar fill
	_bar_fill = ColorRect.new()
	_bar_fill.position = Vector2(px, py + 68.0)
	_bar_fill.size     = Vector2(0.0, BAR_H)
	_bar_fill.color    = Color(0.22, 0.50, 0.92, 0.88)
	_canvas.add_child(_bar_fill)

	# Bar text (centered on bar)
	_bar_text = _make_lbl("0 / 50 pts", 11, Color(1.0, 1.0, 1.0, 0.95))
	_bar_text.position = Vector2(px, py + 68.0)
	_bar_text.size     = Vector2(pw, BAR_H)
	_bar_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar_text.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_canvas.add_child(_bar_text)

	# Next tier label
	_next_lbl = _make_lbl("► Extra Visual Effects", 12, Color(1.0, 0.85, 0.2, 0.9))
	_next_lbl.position = Vector2(px + 6.0, py + 92.0)
	_next_lbl.size     = Vector2(pw - 12.0, 18.0)
	_next_lbl.clip_text = true
	_canvas.add_child(_next_lbl)

	# Unlock count
	_count_lbl = _make_lbl("0 / 5 TIERS UNLOCKED", 10, Color(0.65, 0.65, 0.65, 0.75))
	_count_lbl.position = Vector2(px + 6.0, py + 114.0)
	_count_lbl.size     = Vector2(pw - 12.0, 16.0)
	_canvas.add_child(_count_lbl)

	_refresh_ui()

# ── Helper ────────────────────────────────────────────────────────────────────

func _make_lbl(text: String, font_size: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 1)
	return lbl
