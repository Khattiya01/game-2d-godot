extends CanvasLayer

const USERNAMES := [
	"NeonFighter", "BlueStorm", "RedBlaze", "PixelKing", "StreamVip",
	"User01", "User02", "User03", "GamerXx", "TikTokFan",
	"Viewer99", "RoseGifter", "TeamPlayer", "GodotFan", "LiveWatcher",
]

@onready var panel: PanelContainer = $PanelContainer
@onready var auto_btn: Button = $PanelContainer/VBox/AutoDemoButton
@onready var boss_lv_label: Label = $PanelContainer/VBox/BossRow/BossLvLabel


var _auto_active: bool = false
var _auto_timer: float = 0.0
var _auto_step: int = 0
var _atk_mode_btns: Dictionary = {}  # mode_id → Button for highlight tracking

func _arena() -> Node:
	return get_parent()

func _ready() -> void:
	panel.visible = true
	# Hide legacy / redundant controls
	$PanelContainer/VBox/AtkModeLabel.visible = false
	$PanelContainer/VBox/AtkModeRow.visible = false
	$PanelContainer/VBox/AtkModeRow2.visible = false
	$PanelContainer/VBox/GiftRow.visible = false
	# Dynamic Chaos FX section
	var vbox: VBoxContainer = $PanelContainer/VBox
	var sep := HSeparator.new()
	vbox.add_child(sep)
	var chaos_lbl := Label.new()
	chaos_lbl.text = "── Chaos FX ──"
	chaos_lbl.add_theme_color_override("font_color", Color(0.9, 0.5, 1.0, 1.0))
	chaos_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(chaos_lbl)
	var storm_btn := Button.new()
	storm_btn.text = "⚡ Electric Storm"
	storm_btn.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0, 1.0))
	storm_btn.pressed.connect(_on_storm_pressed)
	vbox.add_child(storm_btn)
	# Private Ultimate section
	vbox.add_child(HSeparator.new())
	var pult_lbl := Label.new()
	pult_lbl.text = "── Private Ultimate ──"
	pult_lbl.add_theme_color_override("font_color", Color(0.9, 1.0, 0.55, 1.0))
	pult_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(pult_lbl)
	var pult_row := HBoxContainer.new()
	vbox.add_child(pult_row)
	var dragon_btn := Button.new()
	dragon_btn.text = "Dragon Soul A"
	dragon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dragon_btn.add_theme_color_override("font_color", Color(0.4, 1.0, 0.85, 1.0))
	dragon_btn.pressed.connect(_on_private_ult_pressed.bind(1))
	pult_row.add_child(dragon_btn)
	var demon_btn2 := Button.new()
	demon_btn2.text = "Demon King B"
	demon_btn2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	demon_btn2.add_theme_color_override("font_color", Color(0.75, 0.1, 1.0, 1.0))
	demon_btn2.pressed.connect(_on_private_ult_pressed.bind(2))
	pult_row.add_child(demon_btn2)

	# Auto Attack Mode selector
	vbox.add_child(HSeparator.new())
	var atk_mode_lbl := Label.new()
	atk_mode_lbl.text = "── Auto Attack Mode ──"
	atk_mode_lbl.add_theme_color_override("font_color", Color(1.0, 0.78, 0.20, 1.0))
	atk_mode_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(atk_mode_lbl)
	# [mode_id, button_label]
	var atk_modes := [
		["rnd",        "🎲 Random"],
		["basic",      "👊 Basic"],
		["dash_t1",    "💨 Dash"],
		["shield_t1",  "🛡 Shield"],
		["buff_t1",    "⚡ Buff ATK"],
		["buff_t2",    "🌿 Buff T2"],
		["attack_t2",  "T2 Rose"],
		["attack_t3",  "T3 Cream"],
		["attack_t4a", "T4a Vortex"],
		["attack_t4b", "T4b Palm"],
		["attack_t4c", "T4c Beam"],
		["attack_t4d", "T4d Whale"],
	]
	var atk_row: HBoxContainer = null
	for i in atk_modes.size():
		if i % 2 == 0:
			atk_row = HBoxContainer.new()
			vbox.add_child(atk_row)
		var mid: String = atk_modes[i][0]
		var mlabel: String = atk_modes[i][1]
		var abtn := Button.new()
		abtn.text = mlabel
		abtn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Highlight the default (attack_t2 = current arena default)
		var is_default: bool = mid == "attack_t2"
		abtn.add_theme_color_override("font_color",
			Color(1.0, 0.85, 0.0, 1.0) if is_default else Color(0.62, 0.62, 0.62, 1.0))
		abtn.pressed.connect(_set_auto_atk_mode.bind(mid))
		atk_row.add_child(abtn)
		_atk_mode_btns[mid] = abtn

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
	match _auto_step % 22:
		0, 1:
			a.on_chat(_rnd(), "1", "")
			a.on_chat(_rnd(), "2", "")
		2:
			a.on_gift(_rnd(), "rose", "", 1)          # T2: Sword Qi
		3:
			a.on_gift(_rnd(), "rose", "", 2)          # T2: Dark Needle
		4:
			a.on_gift(_rnd(), "donut", "", 1)         # Shield: Chi Shield
		5:
			a.on_gift(_rnd(), "donut", "", 2)         # Shield: Demon Shell
		6:
			a.on_gift(_rnd(), "panda", "", 1)         # Buff T1: Chi Gathering
		7:
			a.on_gift(_rnd(), "panda", "", 2)         # Buff T1: Blood Rage
		8:
			a.on_gift(_rnd(), "ice_cream", "", 1)     # T3: White Crane + Buff T2: Lotus Veil
		9:
			a.on_gift(_rnd(), "ice_cream", "", 2)     # T3: Tiger Claw + Buff T2: Dark Hunger
		10:
			a.on_gift(_rnd(), "gift_box", "", 1)      # Dash: Cloud Step
		11:
			a.on_gift(_rnd(), "gift_box", "", 2)      # Dash: Shadow Blink
		12:
			a.on_gift(_rnd(), "rose_bouquet", "", 1)  # T4a: Tai Chi Vortex
		13:
			a.on_gift(_rnd(), "rose_bouquet", "", 2)  # T4a: Dark Tornado
		14:
			a.on_chat(_rnd(), "1", "")
			a.on_chat(_rnd(), "2", "")
		15:
			a.debug_spawn_skill("attack_t4b", 1)      # T4b: Heaven Palm
		16:
			a.debug_spawn_skill("attack_t4b", 2)      # T4b: Shadow Eruption
		17:
			a.debug_spawn_skill("attack_t4c", 1)      # T4c: White Dragon Beam
		18:
			a.debug_spawn_skill("attack_t4c", 2)      # T4c: Black Serpent
		19:
			a.on_gift(_rnd(), "whale_gift", "", 1)    # T4d: Transcendence (A)
		20:
			a.on_gift(_rnd(), "whale_gift", "", 2)    # T4d: Abyss Annihilation (B)
		21:
			a.on_chat(_rnd(), "1", "")
			a.on_chat(_rnd(), "2", "")
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
	if _auto_active:
		_arena().start_game()
		GameManager.start_game()
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
	GameManager.start_game()

func _on_atk_mode_pressed(_mode: int) -> void:
	pass  # legacy — attack mode replaced by team skill system

func _on_storm_pressed() -> void:
	_arena().spawn_electric_storm()

func _on_private_ult_pressed(team: int) -> void:
	# Force-fire by filling the first alive avatar's meter to 100
	var arena := _arena()
	var list: Array = arena._avatars_a if team == 1 else arena._avatars_b
	for av in list:
		if is_instance_valid(av) and av.get("_alive") and not av.get("_respawning"):
			if av.has_method("add_private_ult"):
				av.add_private_ult(100.0)
			break

func _refresh_atk_ui(_mode: int) -> void:
	pass  # legacy — no-op

func _set_auto_atk_mode(mode: String) -> void:
	var arena := _arena()
	if arena:
		arena.auto_attack_mode = mode
	for mid in _atk_mode_btns:
		var btn: Button = _atk_mode_btns[mid]
		if mid == mode:
			btn.add_theme_color_override("font_color", Color(1.0, 0.85, 0.0, 1.0))
		else:
			btn.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62, 1.0))
