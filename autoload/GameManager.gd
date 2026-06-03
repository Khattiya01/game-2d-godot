extends Node

# ── Patch ─────────────────────────────────────────────────────────────────────
const current_patch: String = "wudang_dark"  # Team A = Wudang (white/cyan), Team B = Demon Cult (black/purple)

# ── State ─────────────────────────────────────────────────────────────────────
enum GameState { WAITING, COUNTDOWN, PLAYING, GAME_OVER }
var current_state: GameState = GameState.WAITING

# ── Timer ─────────────────────────────────────────────────────────────────────
@export var game_duration: float = 120.0
var time_remaining: float = game_duration

# ── Score ─────────────────────────────────────────────────────────────────────
var score: Dictionary = { "team_a": 0, "team_b": 0 }

# ── Ultimate state (written by UltimateController) ────────────────────────────
var in_ultimate_mode: bool = false

# ── Internal ──────────────────────────────────────────────────────────────────
var _like_accumulator: int = 0
var _last_timer_second: int = -1

const GIFT_TABLE: Dictionary = {
	# 1B gifts — Tier 1 skills
	"rose":         { "score": 1,  "tier": "small",    "exp": 10,  "hp": 5,   "meter": 2,   "skill_type": "attack_t2" },
	"donut":        { "score": 1,  "tier": "small",    "exp": 10,  "hp": 0,   "meter": 2,   "skill_type": "shield_t1" },
	"gift_box":     { "score": 1,  "tier": "small",    "exp": 10,  "hp": 0,   "meter": 2,   "skill_type": "dash_t1"   },
	"panda":        { "score": 1,  "tier": "small",    "exp": 10,  "hp": 0,   "meter": 2,   "skill_type": "buff_t1"   },
	# 5B — attack T3 + team buff T2
	"ice_cream":    { "score": 3,  "tier": "medium",   "exp": 25,  "hp": 20,  "meter": 5,   "skill_type": "attack_t3", "skill_type_2": "buff_t2" },
	# 10B — attack T4a AoE
	"rose_bouquet": { "score": 5,  "tier": "medium",   "exp": 50,  "hp": 50,  "meter": 8,   "skill_type": "attack_t4a" },
	# 50B+ — beam T4c + cinematic ultimate charge
	"universe":     { "score": 10, "tier": "ultimate", "exp": 250, "hp": 150, "meter": 100, "skill_type": "attack_t4c" },
	# 100B+ — nova T4d (donation_value > 100 also routes here)
	"whale_gift":   { "score": 20, "tier": "ultimate", "exp": 500, "hp": 200, "meter": 0,   "skill_type": "attack_t4d" },
}

# ── Signals ───────────────────────────────────────────────────────────────────
signal game_state_changed(new_state: GameState)
signal score_changed(team: String, new_score: int)
signal timer_updated(seconds_left: float)
signal game_over(winner: String)
signal spawn_avatar_requested(user_data: Dictionary)
signal trigger_effect_requested(effect_data: Dictionary)
signal like_event(data: Dictionary)
signal neutral_effect_requested(effect_data: Dictionary)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	time_remaining = game_duration
	print("[GameManager] Ready  duration=%.0fs  state=%s" % [
		game_duration, GameState.keys()[current_state]
	])


# ── Game Flow ─────────────────────────────────────────────────────────────────

# Enters COUNTDOWN, waits 3 s, then starts the game.
func start_countdown() -> void:
	_set_state(GameState.COUNTDOWN)
	print("[GameManager] Countdown — game begins in 3 s…")
	await get_tree().create_timer(3.0).timeout
	# Guard: only start if nothing cancelled the countdown (e.g. reset).
	if current_state == GameState.COUNTDOWN:
		start_game()

# Resets scores and timer, enters PLAYING.
func start_game() -> void:
	score          = { "team_a": 0, "team_b": 0 }
	time_remaining = game_duration
	_like_accumulator = 0
	_last_timer_second = -1
	ComboTracker.reset_combos()
	_set_state(GameState.PLAYING)
	print("[GameManager] Game started  duration=%.0fs" % game_duration)

# Returns to WAITING with blank scores.
func reset_game() -> void:
	score          = { "team_a": 0, "team_b": 0 }
	time_remaining = game_duration
	_like_accumulator = 0
	_last_timer_second = -1
	ComboTracker.reset_combos()
	_set_state(GameState.WAITING)
	print("[GameManager] Reset → WAITING")

# ── Score ─────────────────────────────────────────────────────────────────────

# Adds amount to team's score (clamped to >= 0) and emits score_changed.
func add_score(team: String, amount: int) -> void:
	if not score.has(team):
		push_warning("[GameManager] add_score — unknown team: '%s'" % team)
		return
	score[team] = maxi(0, score[team] + amount)
	score_changed.emit(team, score[team])

# Returns "team_a", "team_b", or "draw". Call only when GAME_OVER.
func get_winner() -> String:
	if score["team_a"] > score["team_b"]:
		return "team_a"
	elif score["team_b"] > score["team_a"]:
		return "team_b"
	return "draw"

# ── TikTok Event Handlers ─────────────────────────────────────────────────────

# Processes a chat event; emits spawn_avatar_requested when message is "1" or "2".
# Expected keys: username, message, avatar
func on_chat_received(data: Dictionary) -> void:
	if current_state != GameState.PLAYING:
		return
	var msg := str(data.get("message", "")).strip_edges()
	var team: String
	match msg:
		"1": team = "team_a"
		"2": team = "team_b"
		_:   return  # Ignore any other chat message
	spawn_avatar_requested.emit({
		"username": data.get("username", ""),
		"avatar":   data.get("avatar",   ""),
		"team":     team,
		"message":  msg,
	})

# Processes a gift event; emits trigger_effect_requested and updates score.
# Expected keys: gift (name), team ("team_a"/"team_b"), username, avatar
# Optional: donation_value (float, baht) — overrides skill tier when > 10B:
#   >10–50B → attack_t4b,  >50–100B → attack_t4c,  >100B → attack_t4d
func on_gift_received(data: Dictionary) -> void:
	if current_state != GameState.PLAYING:
		return
	var gift_name := str(data.get("gift", "")).to_lower().strip_edges()
	var entry: Dictionary = GIFT_TABLE.get(gift_name, {})
	if entry.is_empty():
		push_warning("[GameManager] on_gift_received — unrecognised gift: '%s'" % gift_name)
		return
	var team := str(data.get("team", ""))
	var username := str(data.get("username", ""))

	# Resolve skill_type — donation_value overrides gift-based routing for high-value gifts
	var skill_type: String = entry.get("skill_type", "")
	var skill_type_2: String = entry.get("skill_type_2", "")
	var donation_value: float = float(data.get("donation_value", -1.0))
	if donation_value > 10.0:
		skill_type_2 = ""
		if donation_value <= 50.0:
			skill_type = "attack_t4b"
		elif donation_value <= 100.0:
			skill_type = "attack_t4c"
		else:
			skill_type = "attack_t4d"

	# Award EXP to the donor's avatar
	if username != "" and entry.get("exp", 0) > 0:
		PlayerStats.add_exp(username, entry["exp"], "donate")
	trigger_effect_requested.emit({
		"gift":           gift_name,
		"tier":           entry["tier"],
		"team":           team,
		"user":           username,
		"hp":             entry.get("hp", 0),
		"skill_type":     skill_type,
		"skill_type_2":   skill_type_2,
		"donation_value": donation_value,
	})
	add_score(team, entry["score"])
	ComboTracker.add_donation(team)
	var meter_pct: float = float(entry.get("meter", 0))
	if meter_pct > 0.0:
		UltimateCharger.add_charge(team, meter_pct)
	print("[GameManager] gift=%-12s  tier=%-8s  skill=%-12s  team=%s  +%d score  +%d EXP" % [
		gift_name, entry["tier"], skill_type, team, entry["score"], entry.get("exp", 0)
	])

# Accumulates likes; emits a micro effect for every 10 likes received.
# Expected keys: count, username, team
func on_like_received(data: Dictionary) -> void:
	if current_state != GameState.PLAYING:
		return
	var username := str(data.get("username", ""))
	var count := int(data.get("count", 1))
	var team := str(data.get("team", ""))
	if username != "":
		PlayerStats.add_exp(username, count, "like")
	ComboTracker.add_like(team)
	like_event.emit(data)
	_like_accumulator += count
	while _like_accumulator >= 10:
		_like_accumulator -= 10
		trigger_effect_requested.emit({
			"gift": "like",
			"tier": "micro",
			"team": team,
			"user": username,
		})

# ── Internal Helpers ──────────────────────────────────────────────────────────

# Sets current_state and broadcasts game_state_changed.
func _set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)
	print("[GameManager] ── state → %s" % GameState.keys()[new_state])
