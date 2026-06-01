extends Node

## AutoLoad: per-stream stats tracker — donors, kills, levels, boss clears.

signal ranking_changed()
signal new_milestone(player_id: String, type: String)

# { player_id: { team, donation_score, kill_count, level, boss_clears } }
var _data: Dictionary = {}

func _ready() -> void:
	PlayerStats.level_changed.connect(_on_level_changed)
	PlayerStats.player_died.connect(_on_player_died)
	GameManager.trigger_effect_requested.connect(_on_effect_requested)
	GameManager.spawn_avatar_requested.connect(_on_spawn_requested)
	GameManager.game_state_changed.connect(_on_state_changed)
	BossManager.boss_defeated.connect(_on_boss_defeated)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _entry(pid: String) -> Dictionary:
	if not _data.has(pid):
		_data[pid] = { "team": "", "donation_score": 0, "kill_count": 0, "level": 1, "boss_clears": 0 }
	return _data[pid]

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_spawn_requested(data: Dictionary) -> void:
	var pid := str(data.get("username", ""))
	if pid.is_empty():
		return
	_entry(pid)["team"] = str(data.get("team", ""))

func _on_effect_requested(data: Dictionary) -> void:
	var tier := str(data.get("tier", ""))
	if tier == "micro" or tier.is_empty():
		return
	var pid := str(data.get("user", ""))
	if pid.is_empty():
		return
	var gift := str(data.get("gift", ""))
	var pts: int = GameManager.GIFT_TABLE.get(gift, {}).get("score", 0)
	if pts <= 0:
		return
	var e := _entry(pid)
	var old: int = e["donation_score"]
	e["donation_score"] += pts
	for m: int in [10, 25, 50, 100, 250, 500]:
		if old < m and e["donation_score"] >= m:
			new_milestone.emit(pid, "donor_%d" % m)
	ranking_changed.emit()

func _on_player_died(_victim: String, killer: String) -> void:
	if killer.is_empty():
		return
	_entry(killer)["kill_count"] += 1
	ranking_changed.emit()

func _on_level_changed(player_id: String, new_level: int) -> void:
	_entry(player_id)["level"] = new_level
	for m: int in [3, 5, 8, 10]:
		if new_level == m:
			new_milestone.emit(player_id, "level_%d" % m)
	ranking_changed.emit()

func _on_boss_defeated(_level: int) -> void:
	for pid: String in _data:
		_data[pid]["boss_clears"] += 1
	ranking_changed.emit()

func _on_state_changed(new_state: GameManager.GameState) -> void:
	if new_state == GameManager.GameState.WAITING:
		_data.clear()
		ranking_changed.emit()

# ── Queries ───────────────────────────────────────────────────────────────────

func get_top_donors(n: int) -> Array:
	return _rank_by("donation_score", n)

func get_top_killers(n: int) -> Array:
	return _rank_by("kill_count", n)

func get_top_levels(n: int) -> Array:
	return _rank_by("level", n)

# Returns sorted array of { player_id, value, team }, capped at n entries.
func _rank_by(field: String, n: int) -> Array:
	var rows: Array = []
	for pid: String in _data:
		rows.append({ "player_id": pid, "value": _data[pid][field], "team": _data[pid]["team"] })
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["value"] > b["value"])
	return rows.slice(0, n)
