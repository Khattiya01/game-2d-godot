extends Node

# Bridges PlayerStats singleton ↔ PlayerAvatar visual instance.
# Created and owned by PlayerAvatar; freed when avatar is freed.

signal level_up_visual(new_level: int)
signal exp_updated  # fired whenever this player gains EXP

var player_id: String = ""
var current_level: int = 1

# Call from PlayerAvatar.setup() after PlayerStats.register_player().
func initialize(pid: String) -> void:
	player_id = pid
	current_level = PlayerStats.get_level(pid)
	PlayerStats.level_changed.connect(_on_level_changed)
	PlayerStats.exp_gained.connect(_on_exp_gained)

func _exit_tree() -> void:
	if PlayerStats.level_changed.is_connected(_on_level_changed):
		PlayerStats.level_changed.disconnect(_on_level_changed)
	if PlayerStats.exp_gained.is_connected(_on_exp_gained):
		PlayerStats.exp_gained.disconnect(_on_exp_gained)

func _on_level_changed(pid: String, new_level: int) -> void:
	if pid != player_id:
		return
	current_level = new_level
	level_up_visual.emit(new_level)

func _on_exp_gained(pid: String, _amount: int) -> void:
	if pid != player_id:
		return
	exp_updated.emit()

# ── Stat helpers (delegate to PlayerStats) ───────────────────────────────────

func get_max_hp() -> int:
	return PlayerStats.get_max_hp(current_level)

func get_damage() -> int:
	return PlayerStats.get_damage(current_level)

func get_size_scale() -> float:
	return PlayerStats.get_size_scale(current_level)

# Returns 0.0–1.0 progress within the current level.
func get_exp_progress() -> float:
	if player_id.is_empty():
		return 0.0
	return PlayerStats.get_exp_progress(player_id)

func get_current_exp() -> int:
	if player_id.is_empty():
		return 0
	return PlayerStats.get_stats(player_id).get("current_exp", 0)
