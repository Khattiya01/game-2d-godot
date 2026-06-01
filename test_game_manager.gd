extends Node

## GameManager integration test suite.
##
## HOW TO RUN:
##   1. Create a new empty scene (e.g. TestScene.tscn).
##   2. Add a plain Node as root, attach this script.
##   3. Press F5 (or Play Scene) — results appear in the Godot Output panel.
##   Do NOT add this to the Arena scene: DemoRunner will conflict with the tests.
##
## WHAT IS TESTED:
##   T1  Initial state is WAITING
##   T2  start_countdown() → COUNTDOWN immediately, PLAYING after 3 s
##   T3  on_chat_received "1" → spawn_avatar_requested emitted (team_a)
##   T4  on_chat_received "2" → spawn_avatar_requested emitted (team_b)
##   T5  on_chat_received unknown message → no signal
##   T6  on_chat_received while not PLAYING → no signal (state-guard)
##   T7  on_gift_received "rose" → score +1, trigger_effect tier "small"
##   T8  on_gift_received "universe" → score +10, tier "ultimate"
##   T9  on_gift_received unknown gift → no crash, no score change
##   T10 on_like_received accumulator < 10 → no micro effect
##   T11 on_like_received accumulator reaches 10 → one micro effect
##   T12 on_like_received 25 at once → two micro effects (one remainder)
##   T13 timer expiry → game_over signal fired, state == GAME_OVER
##   T14 get_winner — all three outcomes
##   T15 reset_game → WAITING, scores zero, time restored

# ── Test infrastructure ───────────────────────────────────────────────────────

var _pass := 0
var _fail := 0

# Signal capture buffers; cleared between logical groups with _flush().
var _spawns:   Array[Dictionary] = []
var _effects:  Array[Dictionary] = []
var _scores:   Array = []   # Array of [team, new_score]
var _states:   Array = []   # Array of GameState values
var _over_result := ""

func _assert(ok: bool, label: String) -> void:
	if ok:
		_pass += 1
		print("    ✓  %s" % label)
	else:
		_fail += 1
		push_error("    ✗  FAIL — %s" % label)

func _section(num: int, title: String) -> void:
	print("\n  T%-2d  %s" % [num, title])

func _flush() -> void:
	_spawns.clear()
	_effects.clear()
	_scores.clear()
	_states.clear()
	_over_result = ""

# ── Entry point ───────────────────────────────────────────────────────────────

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	print("\n" + "═".repeat(56))
	print("  GameManager — Test Suite")
	print("  Godot %s" % Engine.get_version_info().string)
	print("═".repeat(56))

	# Connect signal listeners for the whole session.
	GameManager.spawn_avatar_requested.connect(func(d): _spawns.append(d.duplicate()))
	GameManager.trigger_effect_requested.connect(func(d): _effects.append(d.duplicate()))
	GameManager.score_changed.connect(func(t, v): _scores.append([t, v]))
	GameManager.game_state_changed.connect(func(s): _states.append(s))
	GameManager.game_over.connect(func(w): _over_result = w)

	await _t1_initial_state()
	await _t2_countdown()
	await _t3_t6_chat()
	await _t7_t9_gifts()
	await _t10_t12_likes()
	await _t13_timer_expiry()
	await _t14_winner()
	await _t15_reset()

	_print_summary()

# ── T1 — Initial state ────────────────────────────────────────────────────────

func _t1_initial_state() -> void:
	_section(1, "Initial state")
	GameManager.reset_game()
	_assert(GameManager.current_state == GameManager.GameState.WAITING,
		"state == WAITING")
	_assert(GameManager.score["team_a"] == 0, "score.team_a == 0")
	_assert(GameManager.score["team_b"] == 0, "score.team_b == 0")
	_assert(is_equal_approx(GameManager.time_remaining, GameManager.game_duration),
		"time_remaining == game_duration (%.1f s)" % GameManager.game_duration)

# ── T2 — Countdown ────────────────────────────────────────────────────────────

func _t2_countdown() -> void:
	_section(2, "start_countdown() → COUNTDOWN → PLAYING")
	GameManager.reset_game()
	_flush()

	# Fire without await so we can observe COUNTDOWN immediately.
	GameManager.start_countdown()
	_assert(GameManager.current_state == GameManager.GameState.COUNTDOWN,
		"state == COUNTDOWN immediately after start_countdown()")

	print("    ⏳ waiting 3.5 s for countdown to finish…")
	await get_tree().create_timer(3.5).timeout

	_assert(GameManager.current_state == GameManager.GameState.PLAYING,
		"state == PLAYING after 3 s")
	# State-change log should show COUNTDOWN then PLAYING
	_assert(GameManager.GameState.COUNTDOWN in _states, "game_state_changed(COUNTDOWN) was emitted")
	_assert(GameManager.GameState.PLAYING   in _states, "game_state_changed(PLAYING) was emitted")

# ── T3-T6 — on_chat_received ─────────────────────────────────────────────────

func _t3_t6_chat() -> void:
	_section(3, "on_chat_received — message '1' → team_a spawn")
	GameManager.reset_game()
	GameManager.start_game()
	_flush()

	# NOTE: GameManager reads the "username" key, not "user".
	# The spec example uses {user:"test"} — that key is silently ignored;
	# user_data.username in the emitted signal will be "".
	# Using "username" here to match the actual API and show the correct value.
	GameManager.on_chat_received({"message": "1", "username": "TestUser", "avatar": ""})
	_assert(_spawns.size() == 1,           "spawn_avatar_requested emitted once")
	if _spawns.size() > 0:
		_assert(_spawns[0]["team"] == "team_a",        "emitted team == team_a")
		_assert(_spawns[0]["username"] == "TestUser",  "emitted username == TestUser")
		_assert(_spawns[0]["message"] == "1",          "emitted message == '1'")

	_section(4, "on_chat_received — message '2' → team_b spawn")
	_flush()
	GameManager.on_chat_received({"message": "2", "username": "OtherUser", "avatar": ""})
	_assert(_spawns.size() == 1,           "spawn_avatar_requested emitted once")
	if _spawns.size() > 0:
		_assert(_spawns[0]["team"] == "team_b", "emitted team == team_b")

	_section(5, "on_chat_received — unrecognised message → no signal")
	_flush()
	GameManager.on_chat_received({"message": "hello!", "username": "Spammer"})
	_assert(_spawns.is_empty(), "no spawn emitted for non-join message")

	_section(6, "on_chat_received — state guard (not PLAYING → ignored)")
	GameManager.reset_game()   # → WAITING
	_flush()
	GameManager.on_chat_received({"message": "1", "username": "EarlyBird"})
	_assert(_spawns.is_empty(), "no spawn when state != PLAYING")

# ── T7-T9 — on_gift_received ─────────────────────────────────────────────────

func _t7_t9_gifts() -> void:
	_section(7, "on_gift_received — rose → score +1, tier 'small'")
	GameManager.reset_game()
	GameManager.start_game()
	_flush()

	# Spec example key is "user" — GameManager reads "username"; both shown here.
	GameManager.on_gift_received({"gift": "rose", "team": "team_a",
		"username": "TestUser", "user": "TestUser"})
	_assert(GameManager.score["team_a"] == 1, "score.team_a == 1 (+1 for rose)")
	_assert(not _effects.is_empty(),          "trigger_effect_requested emitted")
	if not _effects.is_empty():
		_assert(_effects[0]["tier"] == "small", "effect tier == 'small'")
		_assert(_effects[0]["gift"] == "rose",  "effect gift == 'rose'")
		_assert(_effects[0]["team"] == "team_a","effect team == 'team_a'")
	_assert(not _scores.is_empty() and _scores[0] == ["team_a", 1],
		"score_changed(team_a, 1) emitted")

	_section(8, "on_gift_received — universe → score +10, tier 'ultimate'")
	_flush()
	GameManager.on_gift_received({"gift": "universe", "team": "team_b", "username": "BigSpender"})
	_assert(GameManager.score["team_b"] == 10, "score.team_b == 10 (+10 for universe)")
	if not _effects.is_empty():
		_assert(_effects[0]["tier"] == "ultimate", "effect tier == 'ultimate'")

	_section(9, "on_gift_received — unknown gift → no crash, no score change")
	_flush()
	var score_before_a := GameManager.score["team_a"]
	var score_before_b := GameManager.score["team_b"]
	GameManager.on_gift_received({"gift": "mystery_box", "team": "team_a"})
	_assert(_effects.is_empty(), "no effect emitted for unknown gift")
	_assert(GameManager.score["team_a"] == score_before_a, "team_a score unchanged")
	_assert(GameManager.score["team_b"] == score_before_b, "team_b score unchanged")

# ── T10-T12 — on_like_received accumulator ────────────────────────────────────

func _t10_t12_likes() -> void:
	_section(10, "on_like_received — 9 likes → no micro effect yet")
	GameManager.reset_game()
	GameManager.start_game()
	_flush()
	GameManager.on_like_received({"count": 9, "username": "Fan"})
	_assert(_effects.is_empty(), "no effect for 9 cumulative likes")

	_section(11, "on_like_received — 1 more (total 10) → one micro effect")
	_flush()
	GameManager.on_like_received({"count": 1, "username": "Fan"})
	_assert(_effects.size() == 1, "exactly 1 micro effect at 10 likes")
	if not _effects.is_empty():
		_assert(_effects[0]["tier"] == "micro", "effect tier == 'micro'")

	_section(12, "on_like_received — 25 at once → 2 effects, 5 remainder")
	_flush()  # accumulator is 0 now (10-9-1 = 0, then 1-1=0 after T11)
	GameManager.on_like_received({"count": 25, "username": "SuperFan"})
	_assert(_effects.size() == 2, "25 likes → 2 micro effects (25÷10=2 r5)")

# ── T13 — Timer expiry ────────────────────────────────────────────────────────

func _t13_timer_expiry() -> void:
	_section(13, "timer expiry → game_over signal, state == GAME_OVER")
	GameManager.reset_game()
	_flush()

	var saved_duration := GameManager.game_duration
	GameManager.game_duration = 1.5   # run a 1.5 s game for the test
	GameManager.start_game()
	_assert(is_equal_approx(GameManager.time_remaining, 1.5),
		"time_remaining set to 1.5 s by start_game()")

	print("    ⏳ waiting 3.0 s for 1.5 s game to end…")
	await get_tree().create_timer(3.0).timeout

	_assert(GameManager.current_state == GameManager.GameState.GAME_OVER,
		"state == GAME_OVER after timer expires")
	_assert(not _over_result.is_empty(), "game_over signal was emitted")
	_assert(_over_result in ["team_a", "team_b", "draw"],
		"game_over winner is valid ('%s')" % _over_result)
	_assert(is_equal_approx(GameManager.time_remaining, 0.0),
		"time_remaining == 0.0")

	GameManager.game_duration = saved_duration  # restore

# ── T14 — get_winner ─────────────────────────────────────────────────────────

func _t14_winner() -> void:
	_section(14, "get_winner() — all three outcomes")
	# Directly write scores to test the logic without side effects.
	GameManager.score["team_a"] = 10
	GameManager.score["team_b"] = 5
	_assert(GameManager.get_winner() == "team_a", "team_a wins (10 vs 5)")

	GameManager.score["team_a"] = 3
	GameManager.score["team_b"] = 8
	_assert(GameManager.get_winner() == "team_b", "team_b wins (3 vs 8)")

	GameManager.score["team_a"] = 7
	GameManager.score["team_b"] = 7
	_assert(GameManager.get_winner() == "draw",   "draw (7 vs 7)")

# ── T15 — reset_game ─────────────────────────────────────────────────────────

func _t15_reset() -> void:
	_section(15, "reset_game() → WAITING, scores 0, time restored")
	# Start from GAME_OVER (where we left off after T13)
	_flush()
	GameManager.reset_game()
	_assert(GameManager.current_state == GameManager.GameState.WAITING,
		"state == WAITING after reset")
	_assert(GameManager.score["team_a"] == 0, "score.team_a reset to 0")
	_assert(GameManager.score["team_b"] == 0, "score.team_b reset to 0")
	_assert(is_equal_approx(GameManager.time_remaining, GameManager.game_duration),
		"time_remaining restored to game_duration (%.1f s)" % GameManager.game_duration)
	_assert(GameManager.GameState.WAITING in _states,
		"game_state_changed(WAITING) emitted")

# ── Summary ───────────────────────────────────────────────────────────────────

func _print_summary() -> void:
	var total := _pass + _fail
	print("\n" + "═".repeat(56))
	if _fail == 0:
		print("  ALL %d TESTS PASSED ✓" % total)
	else:
		print("  %d / %d passed   ← %d FAILED ✗" % [_pass, total, _fail])
	print("═".repeat(56) + "\n")
	if _fail > 0:
		push_error("TestGameManager: %d test(s) failed — see output above." % _fail)
