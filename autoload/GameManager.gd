extends Node

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
	"rose":         { "score": 1,  "tier": "small",    "exp": 10,  "hp": 5,   "meter": 2   },
	"ice_cream":    { "score": 3,  "tier": "medium",   "exp": 25,  "hp": 20,  "meter": 5   },
	"rose_bouquet": { "score": 5,  "tier": "medium",   "exp": 50,  "hp": 50,  "meter": 8   },
	"universe":     { "score": 10, "tier": "ultimate", "exp": 250, "hp": 150, "meter": 100 },
}

# ── Signals ───────────────────────────────────────────────────────────────────
signal game_state_changed(new_state: GameState)
signal score_changed(team: String, new_score: int)
signal timer_updated(seconds_left: float)
signal game_over(winner: String)
signal spawn_avatar_requested(user_data: Dictionary)
signal trigger_effect_requested(effect_data: Dictionary)
signal like_event(data: Dictionary)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	time_remaining = game_duration
	print("[GameManager] Ready  duration=%.0fs  state=%s" % [
		game_duration, GameState.keys()[current_state]
	])

# Counts down the game timer; only runs while PLAYING.
func _process(delta: float) -> void:
	if current_state != GameState.PLAYING:
		return

	time_remaining = maxf(0.0, time_remaining - delta)

	# Emit at most once per second to avoid flooding UI listeners.
	var current_second := int(time_remaining)
	if current_second != _last_timer_second:
		_last_timer_second = current_second
		timer_updated.emit(time_remaining)

	if time_remaining <= 0.0:
		_end_game()

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
	# Award EXP to the donor's avatar
	if username != "" and entry.get("exp", 0) > 0:
		PlayerStats.add_exp(username, entry["exp"], "donate")
	trigger_effect_requested.emit({
		"gift": gift_name,
		"tier": entry["tier"],
		"team": team,
		"user": username,
		"hp":   entry.get("hp", 0),
	})
	add_score(team, entry["score"])
	ComboTracker.add_donation(team)
	var meter_pct: float = float(entry.get("meter", 0))
	if meter_pct > 0.0:
		UltimateCharger.add_charge(team, meter_pct)
	print("[GameManager] gift=%-12s  tier=%-8s  team=%s  +%d score  +%d EXP  +%d HP" % [
		gift_name, entry["tier"], team, entry["score"],
		entry.get("exp", 0), entry.get("hp", 0)
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

# Transitions to GAME_OVER and announces the winner.
func _end_game() -> void:
	_set_state(GameState.GAME_OVER)
	var winner := get_winner()
	game_over.emit(winner)
	print("[GameManager] ══ GAME OVER  winner=%-6s  A=%d  B=%d ══" % [
		winner, score["team_a"], score["team_b"]
	])

# Sets current_state and broadcasts game_state_changed.
func _set_state(new_state: GameState) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)
	print("[GameManager] ── state → %s" % GameState.keys()[new_state])
