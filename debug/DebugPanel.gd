extends CanvasLayer

const USERNAMES := [
	"NeonFighter", "BlueStorm", "RedBlaze", "PixelKing", "StreamVip",
	"User01", "User02", "User03", "GamerXx", "TikTokFan",
	"Viewer99", "RoseGifter", "TeamPlayer", "GodotFan", "LiveWatcher",
]

@onready var panel: PanelContainer = $PanelContainer
@onready var auto_btn: Button = $PanelContainer/VBox/AutoDemoButton
@onready var atk_mode_label: Label = $PanelContainer/VBox/AtkModeLabel
@onready var boss_lv_label: Label = $PanelContainer/VBox/BossRow/BossLvLabel
@onready var atk_btns: Array = []

const ATK_MODE_NAMES := {-1: "Random", 0: "Basic", 1: "Laser", 2: "Chain"}
const ATK_BTN_COLORS := {
	-1: Color(0.85, 0.85, 0.85, 1.0),
	0:  Color(0.5, 0.85, 1.0, 1.0),
	1:  Color(0.4, 0.95, 1.0, 1.0),
	2:  Color(0.9, 0.95, 0.5, 1.0),
}

var _auto_active: bool = false
var _auto_timer: float = 0.0
var _auto_step: int = 0

func _arena() -> Node:
	return get_parent()

func _ready() -> void:
	panel.visible = true
	var row := $PanelContainer/VBox/AtkModeRow
	atk_btns = [row.get_node("AtkRndBtn"), row.get_node("AtkBasicBtn"),
				row.get_node("AtkLaserBtn"), row.get_node("AtkChainBtn")]
	_refresh_atk_ui(-1)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			panel.visible = not panel.visible
			get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	boss_lv_label.text = "Lv.%d" % BossManager.current_boss_level
	if not _auto_active:
		return
	_auto_timer -= delta
	if _auto_timer > 0.0:
		return
	_auto_timer = 2.0
	_run_auto_step()

func _rnd() -> String:
	return USERNAMES[randi() % USERNAMES.size()]

func _run_auto_step() -> void:
	var a := _arena()
	match _auto_step % 10:
		0, 1, 2:
			a.on_chat(_rnd(), "1", "")
			a.on_chat(_rnd(), "2", "")
		3:
			a.on_gift(_rnd(), "rose", "", 1)
		4, 5:
			a.on_chat(_rnd(), str((randi() % 2) + 1), "")
		6:
			a.on_gift(_rnd(), "rose", "", 2)
		7, 8:
			a.on_chat(_rnd(), "1", "")
			a.on_chat(_rnd(), "2", "")
		9:
			a.on_gift(_rnd(), "universe", "", randi() % 2 + 1)
	_auto_step += 1

# ── Button handlers ──────────────────────────────────────────────────────────

func _on_spawn_a_pressed() -> void:
	var a := _arena()
	a.clear_team(1)
	a.on_chat(_rnd(), "1", "")

func _on_spawn_b_pressed() -> void:
	var a := _arena()
	a.clear_team(2)
	a.on_chat(_rnd(), "2", "")

func _on_rose_a_pressed() -> void:
	_arena().on_gift(_rnd(), "rose", "", 1)

func _on_rose_b_pressed() -> void:
	_arena().on_gift(_rnd(), "rose", "", 2)

func _on_ultimate_a_pressed() -> void:
	UltimateController.request_ultimate(1)

func _on_ultimate_b_pressed() -> void:
	UltimateController.request_ultimate(2)

func _on_cancel_ultimate_pressed() -> void:
	for node in get_tree().get_nodes_in_group("ultimate_effects"):
		node.queue_free()
	get_tree().call_group("character_bg", "return_to_idle", "team_a")
	get_tree().call_group("character_bg", "return_to_idle", "team_b")
	CounterUltimate.cancel()

func _on_kill_a_pressed() -> void:
	_arena().kill_debug_first(1)

func _on_kill_b_pressed() -> void:
	_arena().kill_debug_first(2)

func _on_auto_demo_pressed() -> void:
	_auto_active = not _auto_active
	_auto_timer = 0.0
	_auto_step = 0
	auto_btn.text = "■  Stop Demo" if _auto_active else "▶  Auto Demo"
	auto_btn.add_theme_color_override(
		"font_color",
		Color(1.0, 0.4, 0.3, 1.0) if _auto_active else Color(0.3, 1.0, 0.5, 1.0)
	)

func _on_spawn_boss_pressed() -> void:
	BossManager.request_spawn()

func _on_don_scale_pressed(gift_name: String, team: int) -> void:
	_arena().debug_donation_all(team, gift_name)

func _on_like_combo_a_pressed() -> void:
	for i in 3:
		ComboTracker.add_like("team_a")

func _on_like_combo_b_pressed() -> void:
	for i in 3:
		ComboTracker.add_like("team_b")

func _on_donate_combo_a_pressed() -> void:
	for i in 3:
		ComboTracker.add_donation("team_a")

func _on_donate_combo_b_pressed() -> void:
	for i in 3:
		ComboTracker.add_donation("team_b")

func _on_reset_pressed() -> void:
	_auto_active = false
	auto_btn.text = "▶  Auto Demo"
	auto_btn.add_theme_color_override("font_color", Color(0.3, 1.0, 0.5, 1.0))
	_arena().start_game()

func _on_atk_mode_pressed(mode: int) -> void:
	_arena().debug_attack_mode = mode
	_refresh_atk_ui(mode)

func _refresh_atk_ui(mode: int) -> void:
	atk_mode_label.text = "Attack: %s" % ATK_MODE_NAMES.get(mode, "?")
	var active_color: Color = ATK_BTN_COLORS.get(mode, Color.WHITE)
	atk_mode_label.add_theme_color_override("font_color", active_color)
	var modes := [-1, 0, 1, 2]
	for i in atk_btns.size():
		var btn: Button = atk_btns[i]
		var dim: bool = modes[i] != mode
		btn.add_theme_color_override("font_color",
			ATK_BTN_COLORS[modes[i]] if not dim else Color(ATK_BTN_COLORS[modes[i]].r,
			ATK_BTN_COLORS[modes[i]].g, ATK_BTN_COLORS[modes[i]].b, 0.4)
		)
