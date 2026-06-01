extends Node

# Tracks consecutive like and donation combos per team.
# Milestones fire at ×3, ×5, ×10 without resetting (counter continues to next tier).
# Counter resets to 0 at ×10 or after IDLE_RESET_TIME seconds of no activity.

const IDLE_RESET_TIME: float = 5.0

const LIKE_MILESTONES: Dictionary = {
	3:  { "type": "like_x3",  "amount": 10,  "target": "random", "text": "3x LIKE COMBO!  +10 HP  +5% Meter" },
	5:  { "type": "like_x5",  "amount": 25,  "target": "all",    "text": "5x LIKE COMBO!  +25 HP  +20% Meter" },
	10: { "type": "like_x10", "amount": 100, "target": "all",    "text": "LEGENDARY COMBO!  +100 HP  +50% Meter" },
}

const DONATE_MILESTONES: Dictionary = {
	3:  { "type": "donate_x3",  "amount": 15,  "target": "all", "text": "3x DONATION!  +15 HP  +10% Meter" },
	5:  { "type": "donate_x5",  "amount": 50,  "target": "all", "text": "5x DONATION!  +50 HP  +50% ATK!" },
	10: { "type": "donate_x10", "amount": 100, "target": "all", "text": "LEGENDARY DONATION!  +100 HP  +100% ATK!" },
}

var like_combo_count: int = 0
var donate_combo_count: int = 0
var _like_idle_timer: float = 0.0
var _donate_idle_timer: float = 0.0

# Emitted at every milestone; text is the on-screen announcement string.
signal combo_milestone(type: String, count: int, team: String, text: String)
# Arena listens to this to apply healing; target is "random" or "all".
signal heal_requested(team: String, amount: int, target: String)
# Fires when like_combo ≥ 3 AND donate_combo ≥ 3 at the same time.
signal combo_sync(team: String)

func _process(delta: float) -> void:
	if like_combo_count > 0:
		_like_idle_timer -= delta
		if _like_idle_timer <= 0.0:
			like_combo_count = 0

	if donate_combo_count > 0:
		_donate_idle_timer -= delta
		if _donate_idle_timer <= 0.0:
			donate_combo_count = 0

func add_like(team: String) -> void:
	if team.is_empty():
		return
	like_combo_count += 1
	_like_idle_timer = IDLE_RESET_TIME
	_check_like_milestones(team)

func add_donation(team: String) -> void:
	if team.is_empty():
		return
	donate_combo_count += 1
	_donate_idle_timer = IDLE_RESET_TIME
	_check_donate_milestones(team)

func reset_combos() -> void:
	like_combo_count = 0
	donate_combo_count = 0
	_like_idle_timer = 0.0
	_donate_idle_timer = 0.0

func _check_like_milestones(team: String) -> void:
	if not LIKE_MILESTONES.has(like_combo_count):
		return
	var m: Dictionary = LIKE_MILESTONES[like_combo_count]
	combo_milestone.emit(m["type"], like_combo_count, team, m["text"])
	heal_requested.emit(team, m["amount"], m["target"])
	if like_combo_count >= 10:
		like_combo_count = 0
	_check_sync(team)

func _check_donate_milestones(team: String) -> void:
	if not DONATE_MILESTONES.has(donate_combo_count):
		return
	var m: Dictionary = DONATE_MILESTONES[donate_combo_count]
	combo_milestone.emit(m["type"], donate_combo_count, team, m["text"])
	heal_requested.emit(team, m["amount"], m["target"])
	if donate_combo_count >= 10:
		donate_combo_count = 0
	_check_sync(team)

# Fires combo_sync when both like ≥ 3 and donate ≥ 3 at the same moment.
func _check_sync(team: String) -> void:
	if like_combo_count >= 3 and donate_combo_count >= 3:
		combo_sync.emit(team)
		like_combo_count = 0
		donate_combo_count = 0
		print("[ComboTracker] PERFECT SYNC  team=%s" % team)
