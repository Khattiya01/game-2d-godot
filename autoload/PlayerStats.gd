extends Node

# ── EXP Table ─────────────────────────────────────────────────────────────────
# Index N-1 = EXP required to advance from level N to N+1.
const EXP_REQUIRED: Array[int] = [
	50,      # Lv 1 → 2   (total: 50)
	200,     # Lv 2 → 3   (total: 250)
	1000,    # Lv 3 → 4   (total: 1,250)
	4000,    # Lv 4 → 5   (total: 5,250)
	16000,   # Lv 5 → 6   (total: 21,250)
	64000,   # Lv 6 → 7   (total: 85,250)
	256000,  # Lv 7 → 8   (total: 341,250)
	1024000, # Lv 8 → 9   (total: 1,365,250)
	4096000, # Lv 9 → 10  (total: 5,461,250)
]

# ── Signals ───────────────────────────────────────────────────────────────────
signal level_changed(player_id: String, new_level: int)
signal exp_gained(player_id: String, amount: int)
signal player_died(player_id: String, killer_id: String)

# ── Registry ──────────────────────────────────────────────────────────────────
# { player_id: { level, current_exp, kills, likes } }
var _players: Dictionary = {}

# ── Registration ──────────────────────────────────────────────────────────────

func register_player(player_id: String) -> void:
	if _players.has(player_id):
		return
	_players[player_id] = {
		"level": 1,
		"current_exp": 0,
		"kills": 0,
		"likes": 0,
	}
	print("[PlayerStats] Registered: %s" % player_id)

func unregister_player(player_id: String) -> void:
	_players.erase(player_id)

# ── EXP ───────────────────────────────────────────────────────────────────────

# Adds EXP to a player; auto-registers unknown IDs. source: "like", "kill", "boss_clear", etc.
func add_exp(player_id: String, amount: int, source: String = "") -> void:
	if not _players.has(player_id):
		register_player(player_id)
	if amount <= 0:
		return
	var p: Dictionary = _players[player_id]
	p["current_exp"] += amount
	if source == "like":
		p["likes"] += amount
	exp_gained.emit(player_id, amount)
	_check_level_up(player_id)

# ── Kill & Death ──────────────────────────────────────────────────────────────

# Awards killer with victim's level-value EXP, then demotes victim one level.
func on_kill(killer_id: String, victim_id: String) -> void:
	if not _players.has(victim_id):
		return
	var victim_level: int = _players[victim_id]["level"]
	var reward: int = _total_exp_to_reach_level(victim_level + 1)
	if killer_id != "" and _players.has(killer_id):
		_players[killer_id]["kills"] += 1
		add_exp(killer_id, reward, "kill")
	player_died.emit(victim_id, killer_id)
	_reset_on_death(victim_id)

# Grants all registered players EXP equal to 500 × boss_level.
func on_boss_cleared(boss_level: int) -> void:
	var reward: int = 500 * boss_level
	for pid in _players:
		add_exp(pid, reward, "boss_clear")
	print("[PlayerStats] Boss Lv%d cleared — all players +%d EXP" % [boss_level, reward])

# ── Stat Queries ──────────────────────────────────────────────────────────────

# Returns a snapshot dictionary suitable for UI and avatar updates.
func get_stats(player_id: String) -> Dictionary:
	if not _players.has(player_id):
		return {}
	var p: Dictionary = _players[player_id]
	var lv: int = p["level"]
	return {
		"level": lv,
		"current_exp": p["current_exp"],
		"exp_required": get_exp_for_level(lv),
		"exp_progress": get_exp_progress(player_id),
		"max_hp": get_max_hp(lv),
		"damage": get_damage(lv),
		"size_scale": get_size_scale(lv),
		"kills": p["kills"],
		"likes": p["likes"],
		"kill_reward_exp": _total_exp_to_reach_level(lv + 1),
	}

func get_level(player_id: String) -> int:
	return _players.get(player_id, {}).get("level", 1)

# Returns 0.0–1.0 progress within the current level.
func get_exp_progress(player_id: String) -> float:
	if not _players.has(player_id):
		return 0.0
	var p: Dictionary = _players[player_id]
	var needed: int = get_exp_for_level(p["level"])
	if needed <= 0:
		return 1.0
	return float(p["current_exp"]) / float(needed)

# ── Formulas (static-style helpers) ─────────────────────────────────────────

# EXP needed to advance from `level` to `level+1`.
func get_exp_for_level(level: int) -> int:
	if level <= 0:
		return EXP_REQUIRED[0]
	var idx: int = level - 1
	if idx < EXP_REQUIRED.size():
		return EXP_REQUIRED[idx]
	# Beyond the table: multiply ×4 per extra level
	var base: int = EXP_REQUIRED[EXP_REQUIRED.size() - 1]
	for _i in range(level - EXP_REQUIRED.size()):
		base *= 4
	return base

# HP = 100 + (level^1.8 × 50)
func get_max_hp(level: int) -> int:
	return int(100.0 + pow(float(level), 1.8) * 50.0)

# DMG = 10 × (1 + level × 0.15)
func get_damage(level: int) -> int:
	return int(10.0 * (1.0 + float(level) * 0.15))

# SIZE = 1.0 + (level-1) × 0.1  →  Lv1=1.0x, Lv2=1.1x, Lv10=1.9x
func get_size_scale(level: int) -> float:
	return 1.0 + float(level - 1) * 0.1

# ── Internal ──────────────────────────────────────────────────────────────────

func _check_level_up(player_id: String) -> void:
	var p: Dictionary = _players[player_id]
	while p["current_exp"] >= get_exp_for_level(p["level"]):
		p["current_exp"] -= get_exp_for_level(p["level"])
		p["level"] += 1
		level_changed.emit(player_id, p["level"])
		print("[PlayerStats] %s ↑ Lv%d  HP=%d  DMG=%d  SIZE=%.1fx" % [
			player_id, p["level"],
			get_max_hp(p["level"]), get_damage(p["level"]), get_size_scale(p["level"])
		])

# On death: drops one level, resets current_exp to 0.
func _reset_on_death(player_id: String) -> void:
	if not _players.has(player_id):
		return
	var p: Dictionary = _players[player_id]
	p["level"] = maxi(1, p["level"] - 1)
	p["current_exp"] = 0
	print("[PlayerStats] %s died → Lv%d" % [player_id, p["level"]])

# Returns cumulative EXP required to reach `target_level` from Lv1.
func _total_exp_to_reach_level(target_level: int) -> int:
	var total: int = 0
	for lv in range(1, target_level):
		total += get_exp_for_level(lv)
	return total
