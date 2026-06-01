extends Node

## AutoLoad: per-stream peak tracking, achievements, save/load history.
## Creates EndGameScreen CanvasLayer on first GAME_OVER.

signal achievement_unlocked(label: String)

# ── Achievement definitions ───────────────────────────────────────────────────
const ACHIEVEMENT_DEFS: Dictionary = {
	"first_blood":     { "label": "First Blood",      "color": Color(1.0,  0.30, 0.30, 1.0) },
	"power_player":    { "label": "Power Player",     "color": Color(0.6,  0.40, 1.0,  1.0) },
	"legendary":       { "label": "Legendary Lv10",   "color": Color(1.0,  0.85, 0.20, 1.0) },
	"boss_slayer":     { "label": "Boss Slayer",      "color": Color(0.40, 0.90, 0.60, 1.0) },
	"boss_master":     { "label": "Boss Master x3",   "color": Color(0.20, 1.0,  0.50, 1.0) },
	"like_storm":      { "label": "Like Storm 500",   "color": Color(1.0,  0.40, 0.60, 1.0) },
	"whale_alert":     { "label": "Whale Alert!",     "color": Color(0.35, 0.92, 0.78, 1.0) },
	"perfect_sync":    { "label": "Perfect Sync",     "color": Color(0.60, 1.0,  0.80, 1.0) },
	"ultimate_frenzy": { "label": "Ultimate Frenzy",  "color": Color(1.0,  0.55, 0.15, 1.0) },
}

const SAVE_PATH := "user://session_history.json"

# ── Session peaks (never decremented mid-session) ─────────────────────────────
var highest_boss_cleared: int  = 0
var highest_player_level: int  = 1
var total_kills: int           = 0
var total_boss_clears: int     = 0
var total_ultimates: int       = 0
var perfect_syncs: int         = 0
var achievements: Array[String] = []

# ── All-time (persisted) ──────────────────────────────────────────────────────
var all_time_best_boss: int = 0
var all_time_streams: int  = 0
var current_streak: int    = 0

# ── EndGameScreen reference ───────────────────────────────────────────────────
var _screen: Node = null

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_history()
	PlayerStats.player_died.connect(_on_player_died)
	PlayerStats.level_changed.connect(_on_level_changed)
	BossManager.boss_defeated.connect(_on_boss_defeated)
	UltimateController.ultimate_finished.connect(_on_ultimate_finished)
	ComboTracker.combo_sync.connect(_on_combo_sync)
	GameManager.game_state_changed.connect(_on_state_changed)
	StreamerFeed.like_count_updated.connect(_on_like_count_updated)
	StreamerFeed.donation_received.connect(_on_donation_received)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(_screen) or not _screen.visible:
		return
	var is_key   := event is InputEventKey   and (event as InputEventKey).pressed   and not (event as InputEventKey).echo
	var is_click := event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	if is_key or is_click:
		_screen.call("dismiss")

# ── Session reset ─────────────────────────────────────────────────────────────

func reset_session() -> void:
	highest_boss_cleared = 0
	highest_player_level = 1
	total_kills          = 0
	total_boss_clears    = 0
	total_ultimates      = 0
	perfect_syncs        = 0
	achievements.clear()
	if is_instance_valid(_screen):
		_screen.hide()

# ── Event tracking ─────────────────────────────────────────────────────────────

func _on_player_died(_victim: String, killer: String) -> void:
	if killer.is_empty():
		return
	total_kills += 1
	if total_kills == 1:
		_unlock("first_blood")

func _on_level_changed(_pid: String, new_level: int) -> void:
	if new_level > highest_player_level:
		highest_player_level = new_level
	if new_level >= 5:
		_unlock("power_player")
	if new_level >= 10:
		_unlock("legendary")

func _on_boss_defeated(level: int) -> void:
	if level > highest_boss_cleared:
		highest_boss_cleared = level
	total_boss_clears += 1
	if total_boss_clears == 1:
		_unlock("boss_slayer")
	if total_boss_clears >= 3:
		_unlock("boss_master")

func _on_ultimate_finished(_team: String) -> void:
	total_ultimates += 1
	if total_ultimates >= 5:
		_unlock("ultimate_frenzy")

func _on_combo_sync(_team: String) -> void:
	perfect_syncs += 1
	_unlock("perfect_sync")

func _on_like_count_updated(total: int) -> void:
	if total >= 500:
		_unlock("like_storm")

func _on_donation_received(_user: String, _gift: String, _pts: int) -> void:
	if StreamerFeed.session_donate_pts >= 100:
		_unlock("whale_alert")

func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.WAITING:
		reset_session()
	elif new_state == GameManager.GameState.GAME_OVER:
		_on_game_over()

func _on_game_over() -> void:
	_save_history()
	get_tree().create_timer(3.0).timeout.connect(_show_screen, CONNECT_ONE_SHOT)

# ── Achievement unlock ────────────────────────────────────────────────────────

func _unlock(id: String) -> void:
	if achievements.has(id):
		return
	achievements.append(id)
	var lbl: String = ACHIEVEMENT_DEFS.get(id, {}).get("label", id)
	achievement_unlocked.emit(lbl)
	print("[SessionStats] Achievement: %s" % lbl)

# ── Snapshot ──────────────────────────────────────────────────────────────────

func get_snapshot() -> Dictionary:
	var ach_data: Array = []
	for id: String in achievements:
		var def: Dictionary = ACHIEVEMENT_DEFS.get(id, {})
		ach_data.append({
			"label": def.get("label", id),
			"color": def.get("color", Color(0.7, 0.7, 0.7, 1.0)),
		})
	return {
		"highest_boss_cleared":  highest_boss_cleared,
		"next_goal_boss":        highest_boss_cleared + 1,
		"highest_player_level":  highest_player_level,
		"total_kills":           total_kills,
		"total_boss_clears":     total_boss_clears,
		"total_ultimates":       total_ultimates,
		"session_likes":         StreamerFeed.session_likes,
		"session_donation_pts":  StreamerFeed.session_donate_pts,
		"achievements":          ach_data,
		"top_donors":            Leaderboard.get_top_donors(5),
		"top_killers":           Leaderboard.get_top_killers(5),
		"top_levels":            Leaderboard.get_top_levels(5),
		"all_time_best_boss":    all_time_best_boss,
		"total_streams":         all_time_streams,
		"current_streak":        current_streak,
	}

# ── EndGameScreen lifecycle ───────────────────────────────────────────────────

func _show_screen() -> void:
	if not is_instance_valid(_screen):
		var script: GDScript = load("res://scenes/EndGameScreen.gd")
		_screen = CanvasLayer.new()
		_screen.set_script(script)
		add_child(_screen)
	_screen.call("show_results", get_snapshot())

# ── File I/O ──────────────────────────────────────────────────────────────────

func _save_history() -> void:
	if highest_boss_cleared > 0:
		current_streak += 1
	else:
		current_streak = 0
	all_time_streams  += 1
	all_time_best_boss = maxi(all_time_best_boss, highest_boss_cleared)

	var data: Dictionary = {
		"last_session": {
			"date":                   Time.get_date_string_from_system(),
			"highest_boss_cleared":   highest_boss_cleared,
			"highest_player_level":   highest_player_level,
			"total_likes":            StreamerFeed.session_likes,
			"total_donation_pts":     StreamerFeed.session_donate_pts,
			"achievements_count":     achievements.size(),
		},
		"all_time": {
			"best_boss_cleared": all_time_best_boss,
			"total_streams":     all_time_streams,
			"streak":            current_streak,
		},
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
		print("[SessionStats] Saved → %s" % SAVE_PATH)

func _load_history() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not (parsed is Dictionary):
		return
	var at: Dictionary = (parsed as Dictionary).get("all_time", {})
	all_time_best_boss = int(at.get("best_boss_cleared", 0))
	all_time_streams   = int(at.get("total_streams", 0))
	current_streak     = int(at.get("streak", 0))
	print("[SessionStats] Loaded  streams=%d  best_boss=%d  streak=%d" % [
		all_time_streams, all_time_best_boss, current_streak
	])
