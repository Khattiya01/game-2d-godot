extends Node

## Automated demo driver — add as a child of the Arena scene.
## Calls the same on_chat / on_gift API that WebSocketManager will use,
## so all behaviour tested here is identical to a live TikTok session.

@export var auto_start: bool = true
@export_range(0.5, 5.0, 0.1) var spawn_min: float = 1.0
@export_range(0.5, 8.0, 0.1) var spawn_max: float = 3.0
@export_range(2.0, 30.0, 0.5) var gift_interval: float = 5.0
@export_range(5.0, 60.0, 1.0) var ultimate_interval: float = 15.0
@export_range(3.0, 30.0, 0.5) var skill_interval: float = 8.0  # dash / shield / buff cycle

const USERNAMES := [
	"NeonFighter", "BlueStorm", "RedBlaze", "PixelKing", "StreamVip",
	"User_01", "User_02", "GamerXx", "TikTokFan", "Viewer99",
	"RoseGifter", "TeamPlayer", "GodotFan", "LiveWatcher", "CheerLeader",
	"DragonSlayer", "NightOwl", "CyberWolf", "StarDust", "MoonLight",
]

@onready var _arena: Node = get_parent()

var _running: bool = false
var _spawn_t: float = 0.0
var _gift_t: float = 0.0
var _ult_t: float = 0.0
var _skill_t: float = 0.0
var _skill_step: int = 0
var _event_count: int = 0

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_log("Ready  auto_start=%s  spawn=[%.1f,%.1f]s  gift=%.1fs  ult=%.1fs" % [
		auto_start, spawn_min, spawn_max, gift_interval, ultimate_interval
	])
	if auto_start:
		call_deferred("start")

func _process(delta: float) -> void:
	if not _running:
		return

	_spawn_t -= delta
	_gift_t -= delta
	_ult_t -= delta
	_skill_t -= delta

	if _spawn_t <= 0.0:
		_do_spawn()
		_spawn_t = randf_range(spawn_min, spawn_max)

	if _gift_t <= 0.0:
		_do_gift()
		_gift_t = gift_interval

	if _ult_t <= 0.0:
		_do_ultimate()
		_ult_t = ultimate_interval

	if _skill_t <= 0.0:
		_do_support_skill()
		_skill_t = skill_interval

# ── Public API ───────────────────────────────────────────────────────────────

func start() -> void:
	_event_count = 0
	_spawn_t = randf_range(spawn_min, spawn_max)
	_gift_t = gift_interval
	_ult_t = ultimate_interval
	_skill_t = skill_interval * 0.5  # first skill fires at half interval
	_skill_step = 0
	_running = true
	_arena.start_game()
	_log("─── Demo START ────────────────────────────────────────")

func stop() -> void:
	_running = false
	_log("─── Demo STOP  events=%d ──────────────────────────────" % _event_count)

# ── Event drivers ────────────────────────────────────────────────────────────

func _do_spawn() -> void:
	var team := randi() % 2 + 1
	var name := _rnd()
	_log("[SPAWN   ] %-16s → Team %s" % [name, "A" if team == 1 else "B"])
	_arena.on_chat(name, str(team), "")
	_event_count += 1

func _do_gift() -> void:
	var from := randi() % 2 + 1
	var to_s := "B" if from == 1 else "A"
	_log("[ROSE    ] Team %s fires rose  →  Team %s" % ["A" if from == 1 else "B", to_s])
	_arena.on_gift(_rnd(), "rose", "", from)
	_event_count += 1

func _do_ultimate() -> void:
	var from := randi() % 2 + 1
	var to_s := "B" if from == 1 else "A"
	_log("[ULTIMATE] Team %s ULTIMATE!!! →  Team %s  ★★★" % ["A" if from == 1 else "B", to_s])
	_arena.on_gift(_rnd(), "universe", "", from)
	_event_count += 1

func _do_support_skill() -> void:
	# Cycles: gift_box(dash) → donut(shield) → panda(buff_t1) → ice_cream(buff_t2+t3)
	const SKILL_GIFTS := ["gift_box", "donut", "panda", "ice_cream"]
	const SKILL_NAMES := ["Dash", "Shield", "Buff ATK", "Buff T2+T3"]
	var team := randi() % 2 + 1
	var idx := _skill_step % SKILL_GIFTS.size()
	var gift: String = SKILL_GIFTS[idx]
	_log("[SKILL   ] Team %s  %s (%s)" % ["A" if team == 1 else "B", SKILL_NAMES[idx], gift])
	_arena.on_gift(_rnd(), gift, "", team)
	_skill_step += 1
	_event_count += 1

# ── Helpers ──────────────────────────────────────────────────────────────────

func _rnd() -> String:
	return USERNAMES[randi() % USERNAMES.size()]

func _log(msg: String) -> void:
	print("[DemoRunner  t=%6.1fs]  %s" % [Time.get_ticks_msec() / 1000.0, msg])
