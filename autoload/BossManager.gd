extends Node

enum BossState { IDLE, ANNOUNCING, ACTIVE, RESOLVED }

const AUTO_SPAWN_INTERVAL: float = 240.0   # 4 minutes of duel before auto-spawn
const CLOSE_MATCH_GAP: int = 20            # score gap that triggers early spawn
const CLOSE_MATCH_MIN_WAIT: float = 60.0   # must wait at least 1 min first
const ANNOUNCE_DURATION: float = 10.0

var current_boss_level: int = 1
var state: BossState = BossState.IDLE
var _arena_ref: Node = null
var _boss_node: Node = null
var _auto_timer: float = 0.0

signal boss_phase_started(level: int)
signal boss_defeated(level: int)
signal boss_failed(level: int)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func register_arena(arena: Node) -> void:
	_arena_ref = arena

func _process(delta: float) -> void:
	if state != BossState.IDLE:
		return
	if not is_instance_valid(_arena_ref) or not _arena_ref.game_active:
		_auto_timer = 0.0
		return
	_auto_timer += delta
	if _auto_timer >= AUTO_SPAWN_INTERVAL:
		_auto_timer = 0.0
		request_spawn()
		return
	if _auto_timer >= CLOSE_MATCH_MIN_WAIT:
		var gap := abs(_arena_ref.score_a - _arena_ref.score_b)
		if gap <= CLOSE_MATCH_GAP:
			_auto_timer = 0.0
			request_spawn()

func request_spawn() -> void:
	if state != BossState.IDLE:
		return
	if not is_instance_valid(_arena_ref):
		push_warning("[BossManager] No arena registered")
		return
	_announce_and_spawn()

func _announce_and_spawn() -> void:
	state = BossState.ANNOUNCING
	_arena_ref.start_boss_announce(current_boss_level)
	await get_tree().create_timer(ANNOUNCE_DURATION).timeout
	if state != BossState.ANNOUNCING:
		return
	_do_spawn()

func _do_spawn() -> void:
	state = BossState.ACTIVE
	_arena_ref.enter_boss_phase()
	var BossScene: PackedScene = load("res://scenes/Boss.tscn")
	_boss_node = BossScene.instantiate()
	_arena_ref.game_layer.add_child(_boss_node)
	_boss_node.setup(current_boss_level, _arena_ref)
	_boss_node.boss_defeated.connect(_on_boss_defeated)
	_boss_node.boss_timed_out.connect(_on_boss_timed_out)
	_arena_ref.register_boss(_boss_node)
	boss_phase_started.emit(current_boss_level)
	print("[BossManager] Boss Lv%d active  HP=%d  DMG=%d  TIME=%ds" % [
		current_boss_level,
		get_boss_hp(current_boss_level),
		get_boss_dmg(current_boss_level),
		int(get_boss_time(current_boss_level))
	])

func _on_boss_defeated() -> void:
	if state != BossState.ACTIVE:
		return
	state = BossState.RESOLVED
	var level := current_boss_level
	_boss_node = null
	current_boss_level += 1
	_auto_timer = 0.0
	PlayerStats.on_boss_cleared(level)
	boss_defeated.emit(level)
	_arena_ref.exit_boss_phase(true, level)
	await get_tree().create_timer(3.0).timeout
	state = BossState.IDLE

func _on_boss_timed_out() -> void:
	if state != BossState.ACTIVE:
		return
	state = BossState.RESOLVED
	var level := current_boss_level
	_boss_node = null
	_auto_timer = 0.0
	boss_failed.emit(level)
	_arena_ref.exit_boss_phase(false, level)
	await get_tree().create_timer(2.0).timeout
	state = BossState.IDLE

# ── Stat formulas ─────────────────────────────────────────────────────────────

func get_boss_hp(level: int) -> int:
	return int(100.0 * pow(1.6, float(level)))

func get_boss_dmg(level: int) -> int:
	return int(25.0 * pow(1.5, float(level)))

func get_boss_time(level: int) -> float:
	return 120.0 + float(level) * 10.0
