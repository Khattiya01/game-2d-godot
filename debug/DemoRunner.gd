extends Node

## Automated demo driver — add as a child of the Arena scene.
## Calls the same on_chat / on_gift API that WebSocketManager will use,
## so all behaviour tested here is identical to a live TikTok session.

@export var auto_start: bool = true
@export var auto_restart: bool = true
@export_range(0.5, 5.0, 0.1) var spawn_min: float = 1.0
@export_range(0.5, 8.0, 0.1) var spawn_max: float = 3.0
@export_range(2.0, 30.0, 0.5) var gift_interval: float = 5.0
@export_range(5.0, 60.0, 1.0) var ultimate_interval: float = 15.0

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
var _event_count: int = 0
var _restart_gen: int = 0   # incremented on start() to cancel stale auto-restarts

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_arena.game_over.connect(_on_game_over)
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

	if _spawn_t <= 0.0:
		_do_spawn()
		_spawn_t = randf_range(spawn_min, spawn_max)

	if _gift_t <= 0.0:
		_do_gift()
		_gift_t = gift_interval

	if _ult_t <= 0.0:
		_do_ultimate()
		_ult_t = ultimate_interval

# ── Public API ───────────────────────────────────────────────────────────────

func start() -> void:
	_restart_gen += 1
	var win_screen := _arena.get_node_or_null("WinScreen")
	if win_screen:
		win_screen.dismiss()
	_event_count = 0
	_spawn_t = randf_range(spawn_min, spawn_max)
	_gift_t = gift_interval
	_ult_t = ultimate_interval
	_running = true
	_arena.start_game()
	_log("─── Demo START (gen=%d) ───────────────────────────────" % _restart_gen)

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

# ── Game-over handler ────────────────────────────────────────────────────────

func _on_game_over(winner: int) -> void:
	stop()
	var result: String = ["DRAW", "TEAM A WINS", "TEAM B WINS"][winner]
	_log("═══ GAME OVER: %s  (total events: %d) ═══" % [result, _event_count])
	if auto_restart:
		var gen := _restart_gen
		await get_tree().create_timer(5.0).timeout
		# Guard: skip if start() was called externally (e.g. DebugPanel Reset)
		if is_inside_tree() and gen == _restart_gen:
			_log("Auto-restarting...")
			start()

# ── Helpers ──────────────────────────────────────────────────────────────────

func _rnd() -> String:
	return USERNAMES[randi() % USERNAMES.size()]

func _log(msg: String) -> void:
	print("[DemoRunner  t=%6.1fs]  %s" % [Time.get_ticks_msec() / 1000.0, msg])
