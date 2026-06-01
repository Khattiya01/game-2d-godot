extends Node

## AutoLoad: session-wide TikTok engagement tracking + streamer feed UI.
## Tracks cumulative likes, donation totals, fires milestones/stretch-goal alerts.
## Builds its own CanvasLayer (layer=2) — no .tscn required.

signal like_count_updated(total: int)
signal donation_received(username: String, gift_name: String, pts: int)
signal milestone_reached(type: String, value: int)

# ── Session state ─────────────────────────────────────────────────────────────
var session_likes: int       = 0
var session_donate_pts: int  = 0

# ── Like milestones (cumulative thresholds) ───────────────────────────────────
const LIKE_MILESTONES: Array[int] = [50, 100, 200, 500, 1000, 5000, 10000]
var _next_like_ms_idx: int = 0

# ── Stretch-goal donation tiers ───────────────────────────────────────────────
const GOAL_TIERS: Array[int]    = [50, 100, 200, 500, 1000]
const GOAL_LABELS: Array[String] = [
	"Extra Visual Effects!",
	"Boss Theme Unlocked!",
	"Special Character!",
	"Legendary Mode!",
	"ULTIMATE STREAM EVENT!",
]
var _goal_tier_idx: int = 0

# ── Layout constants ──────────────────────────────────────────────────────────
const BAR_W: float       = 360.0
const UI_X_A: float      = 12.0
const UI_X_B: float      = 1548.0
const LIKE_Y: float      = 72.0
const GOAL_Y: float      = 126.0
const TOAST_START_Y: float = 72.0
const TOAST_H: float     = 36.0
const TOAST_GAP: float   = 3.0
const MAX_TOASTS: int    = 5
const BANNER_X: float    = 680.0   # center strip: 680-1240 (560px wide)
const BANNER_W: float    = 560.0
const BANNER_Y_HIDE: float = -70.0
const BANNER_Y_SHOW: float = 56.0

# ── Toast appearance ──────────────────────────────────────────────────────────
const TOAST_TIER_COLS: Dictionary = {
	"small":    Color(1.0,  0.55, 0.65, 1.0),
	"medium":   Color(0.35, 0.92, 0.78, 1.0),
	"ultimate": Color(1.0,  0.85, 0.20, 1.0),
}
const GIFT_NAMES: Dictionary = {
	"rose":         "Rose",
	"ice_cream":    "Ice Cream",
	"rose_bouquet": "Rose Bouquet",
	"universe":     "Universe",
}

# ── UI nodes ──────────────────────────────────────────────────────────────────
var _canvas: CanvasLayer       = null

var _like_count_lbl: Label     = null
var _like_bar_fill: ColorRect  = null
var _like_next_lbl: Label      = null

var _goal_fill: ColorRect      = null
var _goal_pts_lbl: Label       = null
var _goal_tier_lbl: Label      = null

var _toasts: Array[Control]    = []

var _banner: Control           = null
var _banner_lbl: Label         = null
var _banner_sub: Label         = null
var _banner_queue: Array[Dictionary] = []
var _banner_busy: bool         = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	GameManager.like_event.connect(_on_like_event)
	GameManager.trigger_effect_requested.connect(_on_gift_effect)
	GameManager.game_state_changed.connect(_on_state_changed)
	Leaderboard.new_milestone.connect(_on_leaderboard_milestone)
	BossManager.boss_defeated.connect(_on_boss_defeated)

# ── Public ────────────────────────────────────────────────────────────────────

func reset_session() -> void:
	session_likes      = 0
	session_donate_pts = 0
	_next_like_ms_idx  = 0
	_goal_tier_idx     = 0
	_refresh_like_ui()
	_refresh_goal_ui()

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_like_event(data: Dictionary) -> void:
	var count := int(data.get("count", 1))
	session_likes += count
	like_count_updated.emit(session_likes)
	_refresh_like_ui()
	while _next_like_ms_idx < LIKE_MILESTONES.size():
		var ms: int = LIKE_MILESTONES[_next_like_ms_idx]
		if session_likes >= ms:
			_next_like_ms_idx += 1
			_push_banner(
				"♥  %s LIKES!" % _fmt_num(ms),
				"Amazing! Keep the love coming!",
				Color(1.0, 0.4, 0.6, 1.0)
			)
			milestone_reached.emit("likes", ms)
		else:
			break

func _on_gift_effect(data: Dictionary) -> void:
	var tier := str(data.get("tier", ""))
	if tier == "micro" or tier.is_empty():
		return
	var gift := str(data.get("gift", ""))
	var user := str(data.get("user", ""))
	if user.is_empty() or gift.is_empty():
		return
	var pts: int = GameManager.GIFT_TABLE.get(gift, {}).get("score", 0)
	if pts <= 0:
		return
	session_donate_pts += pts
	donation_received.emit(user, gift, pts)
	_spawn_toast(user, gift, pts, tier)
	_refresh_goal_ui()
	while _goal_tier_idx < GOAL_TIERS.size():
		var threshold: int = GOAL_TIERS[_goal_tier_idx]
		if session_donate_pts >= threshold:
			var label: String = GOAL_LABELS[_goal_tier_idx]
			_goal_tier_idx += 1
			_push_banner("GOAL %d pts REACHED!" % threshold, label, Color(1.0, 0.85, 0.2, 1.0))
			milestone_reached.emit("donate_goal", threshold)
		else:
			break

func _on_leaderboard_milestone(player_id: String, type: String) -> void:
	var col := Color(0.9, 0.7, 1.0, 1.0)
	var title := ""
	var sub   := ""
	match type:
		"level_3":
			title = "@%s  reached  Level 3!" % player_id
			sub   = "A rising threat on the field!"
			col   = Color(0.7, 0.85, 1.0, 1.0)
		"level_5":
			title = "@%s  reached  Level 5!" % player_id
			sub   = "Formidable power!"
			col   = Color(0.6, 0.4, 1.0, 1.0)
		"level_8":
			title = "@%s  reached  Level 8!" % player_id
			sub   = "LEGENDARY strength!"
			col   = Color(1.0, 0.85, 0.2, 1.0)
		"level_10":
			title = "@%s  reached  Level 10!" % player_id
			sub   = "GODLIKE POWER!"
			col   = Color(1.0, 0.5, 0.0, 1.0)
		"donor_100":
			title = "@%s  donated  100 pts!" % player_id
			sub   = "Top Supporter!"
			col   = Color(0.4, 0.95, 0.85, 1.0)
		"donor_250":
			title = "@%s  donated  250 pts!" % player_id
			sub   = "MEGA Supporter!"
			col   = Color(1.0, 0.85, 0.2, 1.0)
		"donor_500":
			title = "@%s  donated  500 pts!" % player_id
			sub   = "LEGENDARY Supporter!"
			col   = Color(1.0, 0.5, 0.0, 1.0)
		_:
			return
	_push_banner(title, sub, col)

func _on_boss_defeated(level: int) -> void:
	_push_banner(
		"BOSS  LEVEL  %d  CLEARED!" % level,
		"Both teams rewarded with EXP + HP!",
		Color(1.0, 0.85, 0.2, 1.0)
	)

func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.WAITING:
		reset_session()

# ── Milestone banner (queue-based, slides from top) ──────────────────────────

func _push_banner(title: String, subtitle: String, col: Color) -> void:
	_banner_queue.append({ "title": title, "sub": subtitle, "col": col })
	if not _banner_busy:
		_show_next_banner()

func _show_next_banner() -> void:
	if _banner_queue.is_empty():
		_banner_busy = false
		return
	_banner_busy = true
	var item := _banner_queue.pop_front() as Dictionary
	if not is_instance_valid(_banner_lbl):
		_banner_busy = false
		return
	_banner_lbl.text = str(item["title"])
	_banner_sub.text = str(item["sub"])
	_banner_lbl.add_theme_color_override("font_color", item["col"] as Color)
	_banner.position.y = BANNER_Y_HIDE
	_banner.modulate.a = 1.0
	var tw := _banner.create_tween()
	tw.tween_property(_banner, "position:y", BANNER_Y_SHOW, 0.22).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	tw.tween_interval(2.5)
	tw.tween_property(_banner, "position:y", BANNER_Y_HIDE, 0.2).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)
	tw.tween_callback(_show_next_banner)

# ── Donation toast feed ───────────────────────────────────────────────────────

func _spawn_toast(username: String, gift: String, pts: int, tier: String) -> void:
	# Shift existing toasts down to make room at the top.
	for t: Control in _toasts:
		if is_instance_valid(t):
			t.position.y += TOAST_H + TOAST_GAP

	# Evict oldest when feed is full.
	while _toasts.size() >= MAX_TOASTS:
		var old: Control = _toasts.pop_back()
		if is_instance_valid(old):
			old.queue_free()

	var col: Color     = TOAST_TIER_COLS.get(tier, Color(0.9, 0.9, 0.9, 1.0))
	var gift_name: String = GIFT_NAMES.get(gift, gift.capitalize())
	var unit: String   = "pts" if pts > 1 else "pt"

	var c := Control.new()
	c.size     = Vector2(BAR_W, TOAST_H)
	c.position = Vector2(UI_X_B + BAR_W, TOAST_START_Y)   # starts off-screen right
	_canvas.add_child(c)

	var bg := ColorRect.new()
	bg.size  = Vector2(BAR_W, TOAST_H)
	bg.color = Color(col.r * 0.12, col.g * 0.12, col.b * 0.12, 0.88)
	c.add_child(bg)

	var border := ColorRect.new()
	border.size  = Vector2(3.0, TOAST_H)
	border.color = col
	c.add_child(border)

	var lbl := Label.new()
	lbl.text = "@%s   %s   +%d %s" % [username, gift_name, pts, unit]
	lbl.position = Vector2(9.0, 0.0)
	lbl.size     = Vector2(BAR_W - 9.0, TOAST_H)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.clip_text = true
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	lbl.add_theme_constant_override("outline_size", 1)
	c.add_child(lbl)

	_toasts.insert(0, c)

	# Slide in from right.
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(c, "position:x", UI_X_B, 0.18).set_ease(Tween.EASE_OUT)

	# Auto-fade after 4 seconds.
	get_tree().create_timer(4.0).timeout.connect(
		func() -> void:
			if not is_instance_valid(c):
				return
			var ft := c.create_tween()
			ft.tween_property(c, "modulate:a", 0.0, 0.45)
			ft.tween_callback(func() -> void:
				_toasts.erase(c)
				if is_instance_valid(c):
					c.queue_free()
			),
		CONNECT_ONE_SHOT
	)

# ── UI updates ────────────────────────────────────────────────────────────────

func _refresh_like_ui() -> void:
	if not is_instance_valid(_like_count_lbl):
		return
	_like_count_lbl.text = "♥  %s  LIKES" % _fmt_num(session_likes)

	# Progress toward next milestone.
	var prev_ms: int = 0 if _next_like_ms_idx == 0 else LIKE_MILESTONES[_next_like_ms_idx - 1]
	if _next_like_ms_idx < LIKE_MILESTONES.size():
		var next_ms: int = LIKE_MILESTONES[_next_like_ms_idx]
		var ratio: float = float(session_likes - prev_ms) / float(next_ms - prev_ms)
		ratio = clampf(ratio, 0.0, 1.0)
		_like_bar_fill.size.x = BAR_W * ratio
		_like_next_lbl.text   = "Next: %s" % _fmt_num(next_ms)
	else:
		_like_bar_fill.size.x = BAR_W
		_like_next_lbl.text   = "MAX reached!"

func _refresh_goal_ui() -> void:
	if not is_instance_valid(_goal_fill):
		return
	var prev_tier: int = 0 if _goal_tier_idx == 0 else GOAL_TIERS[_goal_tier_idx - 1]
	if _goal_tier_idx < GOAL_TIERS.size():
		var next_tier: int = GOAL_TIERS[_goal_tier_idx]
		var ratio: float   = float(session_donate_pts - prev_tier) / float(next_tier - prev_tier)
		ratio = clampf(ratio, 0.0, 1.0)
		_goal_fill.size.x  = BAR_W * ratio
		_goal_pts_lbl.text = "STREAM GOAL  %d / %d pts" % [session_donate_pts, next_tier]
		_goal_tier_lbl.text = "► %s" % GOAL_LABELS[_goal_tier_idx]
		_goal_tier_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.80))
	else:
		_goal_fill.size.x   = BAR_W
		_goal_pts_lbl.text  = "STREAM GOAL  %d pts  ALL TIERS!" % session_donate_pts
		_goal_tier_lbl.text = "► All goals reached!"
		_goal_tier_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))

# ── UI construction ───────────────────────────────────────────────────────────

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 2
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)
	_build_like_counter()
	_build_goal_bar()
	_build_banner()

func _build_like_counter() -> void:
	var bx: float = UI_X_A
	var by: float = LIKE_Y

	# Dark background
	var bg := ColorRect.new()
	bg.position = Vector2(bx, by)
	bg.size     = Vector2(BAR_W, 50.0)
	bg.color    = Color(0.0, 0.0, 0.0, 0.55)
	_canvas.add_child(bg)

	# Like count label
	_like_count_lbl = Label.new()
	_like_count_lbl.text     = "♥  0  LIKES"
	_like_count_lbl.position = Vector2(bx + 6.0, by + 2.0)
	_like_count_lbl.size     = Vector2(BAR_W - 12.0, 24.0)
	_like_count_lbl.add_theme_font_size_override("font_size", 18)
	_like_count_lbl.add_theme_color_override("font_color", Color(1.0, 0.4, 0.6, 1.0))
	_like_count_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_like_count_lbl.add_theme_constant_override("outline_size", 2)
	_canvas.add_child(_like_count_lbl)

	# Progress bar background
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(bx, by + 30.0)
	bar_bg.size     = Vector2(BAR_W, 10.0)
	bar_bg.color    = Color(0.12, 0.04, 0.08, 0.9)
	_canvas.add_child(bar_bg)

	# Progress bar fill
	_like_bar_fill = ColorRect.new()
	_like_bar_fill.position = Vector2(bx, by + 30.0)
	_like_bar_fill.size     = Vector2(0.0, 10.0)
	_like_bar_fill.color    = Color(1.0, 0.35, 0.55, 0.9)
	_canvas.add_child(_like_bar_fill)

	# "Next: N" micro label
	_like_next_lbl = Label.new()
	_like_next_lbl.text     = "Next: %d" % LIKE_MILESTONES[0]
	_like_next_lbl.position = Vector2(bx + BAR_W - 90.0, by + 30.0)
	_like_next_lbl.size     = Vector2(88.0, 10.0)
	_like_next_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_like_next_lbl.add_theme_font_size_override("font_size", 9)
	_like_next_lbl.add_theme_color_override("font_color", Color(0.85, 0.5, 0.6, 0.75))
	_canvas.add_child(_like_next_lbl)

func _build_goal_bar() -> void:
	var bx: float = UI_X_A
	var by: float = GOAL_Y

	# Dark background
	var bg := ColorRect.new()
	bg.position = Vector2(bx, by)
	bg.size     = Vector2(BAR_W, 42.0)
	bg.color    = Color(0.0, 0.0, 0.0, 0.50)
	_canvas.add_child(bg)

	# Goal pts label
	_goal_pts_lbl = Label.new()
	_goal_pts_lbl.text     = "STREAM GOAL  0 / %d pts" % GOAL_TIERS[0]
	_goal_pts_lbl.position = Vector2(bx + 6.0, by + 2.0)
	_goal_pts_lbl.size     = Vector2(BAR_W - 12.0, 16.0)
	_goal_pts_lbl.add_theme_font_size_override("font_size", 11)
	_goal_pts_lbl.add_theme_color_override("font_color", Color(0.72, 0.88, 1.0, 0.85))
	_goal_pts_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_goal_pts_lbl.add_theme_constant_override("outline_size", 1)
	_canvas.add_child(_goal_pts_lbl)

	# Progress bar background
	var bar_bg := ColorRect.new()
	bar_bg.position = Vector2(bx, by + 19.0)
	bar_bg.size     = Vector2(BAR_W, 8.0)
	bar_bg.color    = Color(0.06, 0.08, 0.14, 0.88)
	_canvas.add_child(bar_bg)

	# Progress bar fill
	_goal_fill = ColorRect.new()
	_goal_fill.position = Vector2(bx, by + 19.0)
	_goal_fill.size     = Vector2(0.0, 8.0)
	_goal_fill.color    = Color(0.3, 0.7, 1.0, 0.85)
	_canvas.add_child(_goal_fill)

	# Tier unlock label
	_goal_tier_lbl = Label.new()
	_goal_tier_lbl.text     = "► %s" % GOAL_LABELS[0]
	_goal_tier_lbl.position = Vector2(bx + 6.0, by + 27.0)
	_goal_tier_lbl.size     = Vector2(BAR_W - 12.0, 14.0)
	_goal_tier_lbl.add_theme_font_size_override("font_size", 11)
	_goal_tier_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75, 0.80))
	_goal_tier_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_goal_tier_lbl.add_theme_constant_override("outline_size", 1)
	_canvas.add_child(_goal_tier_lbl)

func _build_banner() -> void:
	_banner = Control.new()
	_banner.position  = Vector2(BANNER_X, BANNER_Y_HIDE)
	_banner.size      = Vector2(BANNER_W, 52.0)
	_canvas.add_child(_banner)

	var bg := ColorRect.new()
	bg.size  = Vector2(BANNER_W, 52.0)
	bg.color = Color(0.0, 0.0, 0.0, 0.78)
	_banner.add_child(bg)

	var top_bar := ColorRect.new()
	top_bar.size  = Vector2(BANNER_W, 2.0)
	top_bar.color = Color(1.0, 0.85, 0.2, 0.85)
	_banner.add_child(top_bar)

	var bot_bar := ColorRect.new()
	bot_bar.position = Vector2(0.0, 50.0)
	bot_bar.size     = Vector2(BANNER_W, 2.0)
	bot_bar.color    = Color(1.0, 0.85, 0.2, 0.85)
	_banner.add_child(bot_bar)

	_banner_lbl = Label.new()
	_banner_lbl.position = Vector2(8.0, 2.0)
	_banner_lbl.size     = Vector2(BANNER_W - 16.0, 28.0)
	_banner_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_banner_lbl.add_theme_font_size_override("font_size", 20)
	_banner_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2, 1.0))
	_banner_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_banner_lbl.add_theme_constant_override("outline_size", 2)
	_banner_lbl.clip_text = true
	_banner.add_child(_banner_lbl)

	_banner_sub = Label.new()
	_banner_sub.position = Vector2(8.0, 30.0)
	_banner_sub.size     = Vector2(BANNER_W - 16.0, 20.0)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_banner_sub.add_theme_font_size_override("font_size", 13)
	_banner_sub.add_theme_color_override("font_color", Color(0.88, 0.88, 0.88, 0.90))
	_banner_sub.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_banner_sub.add_theme_constant_override("outline_size", 1)
	_banner_sub.clip_text = true
	_banner.add_child(_banner_sub)

# ── Utilities ─────────────────────────────────────────────────────────────────

func _fmt_num(n: int) -> String:
	if n >= 10000:
		return "%dk" % (n / 1000)
	if n >= 1000:
		return "%.1fk" % (float(n) / 1000.0)
	return str(n)
