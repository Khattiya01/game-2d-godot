extends Node2D

const PlayerAvatarScene := preload("res://scenes/PlayerAvatar.tscn")
const GiftAttackScene := preload("res://effects/GiftAttackEffect.tscn")
const CharacterBgScene := preload("res://scenes/CharacterBackground.tscn")
const MicroEffectScene := preload("res://effects/MicroEffect.tscn")
const PlayerAttackScene := preload("res://effects/PlayerAttackEffect.tscn")
const LaserAttackScene := preload("res://effects/LaserAttackEffect.tscn")
const LightningAttackScene := preload("res://effects/LightningAttackEffect.tscn")

@export var zone_a: Rect2 = Rect2(30, 180, 900, 860)
@export var zone_b: Rect2 = Rect2(990, 180, 900, 860)
@export var max_avatars_per_zone: int = 100
@export var match_duration: float = 300.0

@onready var score_a_label: Label = $UILayer/ScoreA
@onready var score_b_label: Label = $UILayer/ScoreB
@onready var timer_label: Label = $UILayer/TimerPanel/TimerLabel
@onready var game_layer: Node2D = $GameLayer

var score_a: int = 0
var score_b: int = 0
var time_remaining: float = 0.0
var game_active: bool = false
var is_boss_phase: bool = false
var debug_attack_mode: int = -1  # -1=random, 0=basic, 1=laser, 2=chain

var _avatars_a: Array[Node] = []
var _avatars_b: Array[Node] = []
var _boss_ref: Node = null            # active boss node (avatars retarget to this)
var _announce_overlay: CanvasLayer = null
var _camera: Camera2D = null
var _boss_overlay: CanvasLayer = null
var _boss_overlay_timer_lbl: Label = null

var _shake_duration: float = 0.0
var _shake_intensity: float = 0.0
# Per-team timed damage multipliers set by donation combos.
var _dmg_buff: Dictionary = {
	"team_a": { "mult": 1.0, "timer": 0.0 },
	"team_b": { "mult": 1.0, "timer": 0.0 },
}

signal game_over(winner: int)

func _ready() -> void:
	var char_bg: Node2D = CharacterBgScene.instantiate()
	add_child(char_bg)
	time_remaining = match_duration
	_refresh_score()
	_refresh_timer()
	UltimateController.register_arena(self)
	BossManager.register_arena(self)
	GameManager.trigger_effect_requested.connect(_on_trigger_effect_requested)
	GameManager.spawn_avatar_requested.connect(_on_spawn_avatar_requested)
	ComboTracker.heal_requested.connect(_on_heal_requested)
	ComboTracker.combo_milestone.connect(_on_combo_milestone)
	ComboTracker.combo_sync.connect(_on_combo_sync)
	_camera = Camera2D.new()
	_camera.position = Vector2(960, 540)
	_camera.zoom = Vector2.ONE
	add_child(_camera)
	_camera.make_current()

func _process(delta: float) -> void:
	if _shake_duration > 0.0:
		_shake_duration -= delta
		_shake_intensity = lerpf(_shake_intensity, 0.0, delta * 10.0)
		game_layer.position = Vector2(
			randf_range(-_shake_intensity, _shake_intensity),
			randf_range(-_shake_intensity, _shake_intensity)
		)
	elif game_layer.position != Vector2.ZERO:
		game_layer.position = Vector2.ZERO

	if not game_active:
		return
	time_remaining = maxf(0.0, time_remaining - delta)
	_refresh_timer()
	if time_remaining == 0.0:
		_end_game()
	for key in _dmg_buff:
		var buff: Dictionary = _dmg_buff[key]
		if buff["timer"] > 0.0:
			buff["timer"] -= delta
			if buff["timer"] <= 0.0:
				buff["mult"] = 1.0
				buff["timer"] = 0.0

func start_game() -> void:
	clear_avatars()
	score_a = 0
	score_b = 0
	time_remaining = match_duration
	game_active = true
	_refresh_score()
	_refresh_timer()

func add_score(team: int, amount: int = 1) -> void:
	if team == 1:
		score_a = maxi(0, score_a + amount)
	elif team == 2:
		score_b = maxi(0, score_b + amount)
	_refresh_score()

func screen_shake(duration: float, intensity: float) -> void:
	_shake_duration = duration
	_shake_intensity = intensity

func knockback_team(team: int) -> void:
	var list := _avatars_a if team == 1 else _avatars_b
	var outer_x := -1.0 if team == 1 else 1.0
	for avatar in list:
		if is_instance_valid(avatar) and avatar.has_method("knockback"):
			avatar.knockback(Vector2(
				outer_x * randf_range(35.0, 95.0) + randf_range(-15.0, 15.0),
				randf_range(-70.0, 70.0)
			))

func damage_team_all(team: int, amount: int) -> void:
	var list := (_avatars_a if team == 1 else _avatars_b).duplicate()
	for av in list:
		if is_instance_valid(av) and av.has_method("take_damage") and av.get("_alive"):
			av.take_damage(amount)

# ── Enemy query ──────────────────────────────────────────────────────────────

func get_nearest_enemy(from_pos: Vector2, my_team: int) -> Node:
	if is_boss_phase and is_instance_valid(_boss_ref):
		return _boss_ref
	return get_nearest_on_team(from_pos, 3 - my_team)

func get_nearest_on_team(from_pos: Vector2, team: int) -> Node:
	var list := _avatars_a if team == 1 else _avatars_b
	var nearest: Node = null
	var nearest_dist := INF
	for av in list:
		if not is_instance_valid(av):
			continue
		if av.get("_alive") == false:  # Skip dead / respawning avatars
			continue
		var d := from_pos.distance_squared_to(av.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = av
	return nearest

func get_zone_center(team: int) -> Vector2:
	return (zone_a if team == 1 else zone_b).get_center()

# ── Avatar death handler ──────────────────────────────────────────────────────

func on_avatar_died(avatar: Node, team: int) -> void:
	if team == 1:
		_avatars_a.erase(avatar)
	else:
		_avatars_b.erase(avatar)
	add_score(3 - team, 1)

# ── Effect spawning ───────────────────────────────────────────────────────────

func spawn_attack_effect(from_pos: Vector2, to_pos: Vector2, target: Node, on_complete: Callable = Callable(), dmg_mult: float = 1.0) -> void:
	var effect: Node2D = PlayerAttackScene.instantiate()
	game_layer.add_child(effect)
	effect.fire({"from_pos": from_pos, "target_pos": to_pos, "target": target, "on_complete": on_complete, "damage_mult": dmg_mult})

func spawn_laser_attack(attacker: Node, target: Node, on_complete: Callable, dmg_mult: float = 1.0) -> void:
	var effect: Node2D = LaserAttackScene.instantiate()
	game_layer.add_child(effect)
	effect.fire({"attacker": attacker, "target": target, "on_complete": on_complete, "damage_mult": dmg_mult})

func spawn_lightning_attack(attacker: Node, target: Node, team: int, on_complete: Callable, dmg_mult: float = 1.0) -> void:
	var effect: Node2D = LightningAttackScene.instantiate()
	game_layer.add_child(effect)
	effect.fire({"attacker": attacker, "target": target, "team": team, "arena": self, "on_complete": on_complete, "damage_mult": dmg_mult})

func get_nearest_on_team_excluding(from_pos: Vector2, team: int, exclude: Array) -> Node:
	var list := _avatars_a if team == 1 else _avatars_b
	var nearest: Node = null
	var nearest_dist := INF
	for av in list:
		if not is_instance_valid(av) or av in exclude:
			continue
		if av.get("_alive") == false:  # Skip dead / respawning avatars
			continue
		var d := from_pos.distance_squared_to(av.global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = av
	return nearest

func trigger_gift_attack(from_team: int) -> void:
	var effect: Node2D = GiftAttackScene.instantiate()
	game_layer.add_child(effect)
	effect.fire(from_team, self)

func trigger_ultimate_attack(from_team: int) -> void:
	UltimateController.request_ultimate(from_team)

# ── Debug helpers ─────────────────────────────────────────────────────────────

func clear_team(team: int) -> void:
	var list := _avatars_a if team == 1 else _avatars_b
	for av in list.duplicate():
		if is_instance_valid(av):
			av.queue_free()
	if team == 1:
		_avatars_a.clear()
	else:
		_avatars_b.clear()

func kill_debug_first(team: int) -> void:
	var list := _avatars_a if team == 1 else _avatars_b
	for av in list.duplicate():
		if is_instance_valid(av) and av.has_method("die"):
			av.die()
			break

# ── TikTok event API ──────────────────────────────────────────────────────────

func on_chat(username: String, message: String, avatar_url: String) -> void:
	match message.strip_edges():
		"1": spawn_avatar(username, 1, avatar_url)
		"2": spawn_avatar(username, 2, avatar_url)

func on_like(username: String, _count: int = 1) -> void:
	var effect: Node2D = MicroEffectScene.instantiate()
	game_layer.add_child(effect)
	# Spawn micro effect at avatar position if found, otherwise random zone
	var avatar := _find_avatar_by_id(username)
	var spawn_pos: Vector2
	if avatar:
		spawn_pos = avatar.global_position
	else:
		var zone := zone_a if randi() % 2 == 0 else zone_b
		spawn_pos = Vector2(
			randf_range(zone.position.x, zone.end.x),
			randf_range(zone.position.y, zone.end.y)
		)
	effect.fire({"position": spawn_pos})

func on_gift(username: String, gift_name: String, avatar_url: String, from_team: int) -> void:
	var team_str := "team_a" if from_team == 1 else "team_b"
	match gift_name.to_lower():
		"rose":
			trigger_gift_attack(from_team)
		"universe":
			UltimateCharger.add_charge(team_str, 100.0)
		"like":
			on_like(username)

func spawn_avatar(username: String, team: int, avatar_url: String) -> void:
	if is_boss_phase:
		return
	var list := _avatars_a if team == 1 else _avatars_b
	if list.size() >= max_avatars_per_zone:
		var oldest: Node = list.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

	var avatar: Node2D = PlayerAvatarScene.instantiate()
	game_layer.add_child(avatar)
	avatar.position = get_zone_center(team)
	avatar.setup(username, team, avatar_url, self)
	avatar.avatar_died.connect(on_avatar_died)
	list.append(avatar)

func clear_avatars() -> void:
	for a in _avatars_a + _avatars_b:
		if is_instance_valid(a):
			a.queue_free()
	_avatars_a.clear()
	_avatars_b.clear()

func _random_zone_pos(team: int) -> Vector2:
	var zone := zone_a if team == 1 else zone_b
	return Vector2(
		randf_range(zone.position.x + 64.0, zone.end.x - 64.0),
		randf_range(zone.position.y + 64.0, zone.end.y - 64.0)
	)

func _refresh_score() -> void:
	score_a_label.text = str(score_a)
	score_b_label.text = str(score_b)

func _refresh_timer() -> void:
	var m := int(time_remaining) / 60
	var s := int(time_remaining) % 60
	timer_label.text = "%d:%02d" % [m, s]

# Spawns a floating gold "+N EXP" label at world_pos (shown on kill).
func spawn_exp_gain_text(world_pos: Vector2, amount: int) -> void:
	if amount <= 0:
		return
	var container := Node2D.new()
	game_layer.add_child(container)
	container.z_index = 10
	container.global_position = world_pos
	var label := Label.new()
	container.add_child(label)
	label.text = "+%d EXP" % amount
	label.position = Vector2(-20, -10)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(container, "global_position:y", world_pos.y - 55.0, 1.5)
	tween.tween_property(container, "modulate:a", 0.0, 1.5).set_delay(0.4)
	tween.set_parallel(false)
	tween.tween_callback(container.queue_free)

# Routes GameManager.trigger_effect_requested into Arena visuals + stat effects.
func _on_trigger_effect_requested(data: Dictionary) -> void:
	var tier := str(data.get("tier", ""))
	var team_str := str(data.get("team", ""))
	var team_int := 1 if team_str == "team_a" else 2
	match tier:
		"micro":
			on_like(str(data.get("user", "")), 1)
		"small", "medium":
			trigger_gift_attack(team_int)
		# "ultimate" tier is intentionally absent: UltimateCharger fires it via meter system
	# Apply HP restore from donation (team-wide)
	var hp: int = int(data.get("hp", 0))
	if hp > 0 and team_str != "":
		heal_team(team_int, hp)

# Returns the first avatar node matching player_id across both teams.
func _find_avatar_by_id(pid: String) -> Node:
	for av in _avatars_a + _avatars_b:
		if is_instance_valid(av) and av.get("player_id") == pid:
			return av
	return null

# ── Combo / Heal handlers ─────────────────────────────────────────────────────

func _on_heal_requested(team: String, amount: int, target: String) -> void:
	var team_int := 1 if team == "team_a" else 2
	if target == "random":
		heal_random_avatar(team_int, amount)
	else:
		heal_team(team_int, amount)

func _on_combo_milestone(type: String, count: int, team: String, text: String) -> void:
	var team_int := 1 if team == "team_a" else 2
	spawn_combo_announce(text, team_int)
	match type:
		"donate_x5":  apply_damage_buff(team_int, 1.5, 5.0)
		"donate_x10": apply_damage_buff(team_int, 2.0, 10.0)
	print("[Arena] Combo: %s x%d  team=%s" % [type, count, team])

func _on_combo_sync(team: String) -> void:
	var team_int := 1 if team == "team_a" else 2
	heal_team(team_int, 75)
	spawn_combo_announce("PERFECT SYNC!  +75 HP  +20% Meter", team_int)
	_spawn_sync_burst(team_int)
	print("[Arena] PERFECT SYNC  team=%s" % team)

# Applies a timed attack multiplier to a team (extends duration if already active).
func apply_damage_buff(team_int: int, mult: float, duration: float) -> void:
	var key := "team_a" if team_int == 1 else "team_b"
	_dmg_buff[key]["mult"] = mult
	_dmg_buff[key]["timer"] = maxf(_dmg_buff[key]["timer"], duration)
	print("[Arena] ATK buff  team=%s  x%.1f  %.0fs" % [key, mult, duration])

# Returns the current attack multiplier for avatars on the given team.
func get_attack_mult(team_int: int) -> float:
	var key := "team_a" if team_int == 1 else "team_b"
	return _dmg_buff[key]["mult"]

# Rainbow firework burst at zone center for PERFECT SYNC event.
func _spawn_sync_burst(team_int: int) -> void:
	var center := get_zone_center(team_int)
	for i in 8:
		var delay := float(i) * 0.16
		var pos := center + Vector2(randf_range(-180.0, 180.0), randf_range(-150.0, 150.0))
		get_tree().create_timer(delay).timeout.connect(_burst_firework.bind(pos))

func heal_team(team: int, amount: int) -> void:
	var list := _avatars_a if team == 1 else _avatars_b
	for av in list:
		if is_instance_valid(av) and av.get("_alive") and not av.get("_respawning"):
			av.heal(amount)

func heal_random_avatar(team: int, amount: int) -> void:
	var list := _avatars_a if team == 1 else _avatars_b
	var candidates: Array = []
	for av in list:
		if is_instance_valid(av) and av.get("_alive") and not av.get("_respawning"):
			candidates.append(av)
	if candidates.is_empty():
		return
	candidates[randi() % candidates.size()].heal(amount)

func spawn_combo_announce(text: String, team: int) -> void:
	var pos: Vector2
	if team == 1:
		pos = zone_a.get_center()
	elif team == 2:
		pos = zone_b.get_center()
	else:
		pos = Vector2(960, 540)  # screen center for boss/global announcements
	var container := Node2D.new()
	game_layer.add_child(container)
	container.z_index = 20
	container.global_position = pos
	var label := Label.new()
	container.add_child(label)
	label.text = text
	label.size = Vector2(300, 40)
	label.position = Vector2(-150, -20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	var color := Color(0.35, 1.0, 0.5, 1.0) if team == 1 else Color(1.0, 0.5, 0.35, 1.0)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 3)
	container.scale = Vector2.ZERO
	var tween := create_tween().set_parallel(true)
	tween.tween_property(container, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(container, "global_position:y", pos.y - 90.0, 1.8).set_delay(0.1)
	tween.tween_property(container, "modulate:a", 0.0, 1.0).set_delay(0.8)
	tween.set_parallel(false)
	tween.tween_callback(container.queue_free)

# ── Boss phase ────────────────────────────────────────────────────────────────

func start_boss_announce(level: int) -> void:
	_remove_announce_overlay()
	_announce_overlay = CanvasLayer.new()
	_announce_overlay.layer = 8
	add_child(_announce_overlay)
	# Dark backdrop
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	_announce_overlay.add_child(bg)
	var bg_tween := bg.create_tween()
	bg_tween.tween_property(bg, "color:a", 0.35, 0.5)
	# Warning text
	var lbl := Label.new()
	lbl.text = "⚠  BOSS LEVEL %d APPROACHING!" % level
	lbl.size = Vector2(900, 60)
	lbl.position = Vector2(510, 460)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 42)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 0.15, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.modulate.a = 0.0
	_announce_overlay.add_child(lbl)
	var lbl_tween := lbl.create_tween()
	lbl_tween.tween_property(lbl, "modulate:a", 1.0, 0.4)
	print("[Arena] Boss Lv%d announcement started" % level)

func enter_boss_phase() -> void:
	is_boss_phase = true
	_remove_announce_overlay()
	for av in _avatars_a + _avatars_b:
		if is_instance_valid(av) and av.has_method("set_boss_phase"):
			av.set_boss_phase(true)
	_show_boss_phase_overlay(BossManager.current_boss_level)
	if is_instance_valid(_camera):
		var t := _camera.create_tween()
		t.tween_property(_camera, "position", Vector2(960, 450), 1.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(_camera, "zoom", Vector2(1.05, 1.05), 1.0) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	print("[Arena] Boss phase entered")

func exit_boss_phase(success: bool, level: int) -> void:
	is_boss_phase = false
	_boss_ref = null
	_remove_boss_phase_overlay()
	if is_instance_valid(_camera):
		var t := _camera.create_tween()
		t.tween_property(_camera, "position", Vector2(960, 540), 0.8) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		t.parallel().tween_property(_camera, "zoom", Vector2.ONE, 0.8) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for av in _avatars_a + _avatars_b:
		if is_instance_valid(av) and av.has_method("set_boss_phase"):
			av.set_boss_phase(false)
	if success:
		var score_bonus := 100 * level
		add_score(1, score_bonus)
		add_score(2, score_bonus)
		_heal_all_half()
		_spawn_boss_defeat_celebration(level)
	else:
		spawn_combo_announce("Boss survived... try again!", 0)
	print("[Arena] Boss phase exited  success=%s  level=%d" % [success, level])

func register_boss(boss_node: Node) -> void:
	_boss_ref = boss_node

# Called each frame by Boss.gd to keep the large overlay timer in sync.
func update_boss_phase_timer(time: float) -> void:
	if not is_instance_valid(_boss_overlay_timer_lbl):
		return
	var secs := int(maxf(0.0, time))
	_boss_overlay_timer_lbl.text = "%d:%02d" % [secs / 60, secs % 60]
	if time <= 30.0:
		_boss_overlay_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.22, 0.22, 1.0))
	elif time <= 60.0:
		_boss_overlay_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2, 1.0))
	else:
		_boss_overlay_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))

func _show_boss_phase_overlay(level: int) -> void:
	_remove_boss_phase_overlay()
	_boss_overlay = CanvasLayer.new()
	_boss_overlay.layer = 9
	add_child(_boss_overlay)

	var px := 660.0
	var py := 962.0
	var pw := 600.0
	var ph := 104.0

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.05, 0.72)
	bg.size = Vector2(pw, ph)
	bg.position = Vector2(px, py)
	_boss_overlay.add_child(bg)

	var border := ColorRect.new()
	border.color = Color(1.0, 0.45, 0.1, 0.6)
	border.size = Vector2(pw, 2.0)
	border.position = Vector2(px, py)
	_boss_overlay.add_child(border)

	var title := Label.new()
	title.text = "BOSS  LV.%d  ——  PHASE TIMER" % level
	title.size = Vector2(pw, 22.0)
	title.position = Vector2(px, py + 6.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", Color(1.0, 0.65, 0.25, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 1)
	_boss_overlay.add_child(title)

	_boss_overlay_timer_lbl = Label.new()
	_boss_overlay_timer_lbl.size = Vector2(pw, 72.0)
	_boss_overlay_timer_lbl.position = Vector2(px, py + 27.0)
	_boss_overlay_timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_overlay_timer_lbl.add_theme_font_size_override("font_size", 56)
	_boss_overlay_timer_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.8, 1.0))
	_boss_overlay_timer_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_boss_overlay_timer_lbl.add_theme_constant_override("outline_size", 4)
	_boss_overlay_timer_lbl.text = "2:00"
	_boss_overlay.add_child(_boss_overlay_timer_lbl)

	_boss_overlay.modulate.a = 0.0
	var t := _boss_overlay.create_tween()
	t.tween_property(_boss_overlay, "modulate:a", 1.0, 0.5)

func _remove_boss_phase_overlay() -> void:
	if is_instance_valid(_boss_overlay):
		_boss_overlay.queue_free()
	_boss_overlay = null
	_boss_overlay_timer_lbl = null

# Full-screen celebration overlay + fireworks on boss defeat.
func _spawn_boss_defeat_celebration(level: int) -> void:
	_spawn_fireworks(level)

	var cl := CanvasLayer.new()
	cl.layer = 12
	add_child(cl)

	# Brief screen flash
	var flash := ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.0)
	flash.anchor_right = 1.0
	flash.anchor_bottom = 1.0
	cl.add_child(flash)
	var flash_t := flash.create_tween()
	flash_t.tween_property(flash, "color:a", 0.55, 0.12)
	flash_t.tween_property(flash, "color:a", 0.0, 0.45)

	# "BOSS DEFEATED!" large pop-in title
	var title := Label.new()
	title.text = "BOSS DEFEATED!"
	title.size = Vector2(1200, 120)
	title.position = Vector2(360, 330)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 90)
	title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.15, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.45, 0.1, 0.0, 1.0))
	title.add_theme_constant_override("outline_size", 7)
	title.pivot_offset = Vector2(600.0, 60.0)
	title.scale = Vector2(0.25, 0.25)
	title.modulate.a = 0.0
	cl.add_child(title)
	var title_t := title.create_tween().set_parallel(true)
	title_t.tween_property(title, "modulate:a", 1.0, 0.22)
	title_t.tween_property(title, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# "LEVEL X CLEARED!" subtitle
	var sub := Label.new()
	sub.text = "LEVEL  %d  CLEARED!" % level
	sub.size = Vector2(900, 60)
	sub.position = Vector2(510, 455)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 44)
	sub.add_theme_color_override("font_color", Color(0.88, 0.55, 1.0, 1.0))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	sub.add_theme_constant_override("outline_size", 4)
	sub.modulate.a = 0.0
	cl.add_child(sub)
	var sub_t := sub.create_tween()
	sub_t.tween_interval(0.18)
	sub_t.tween_property(sub, "modulate:a", 1.0, 0.28)

	# Reward summary line
	var exp_reward := 500 * level
	var score_reward := 100 * level
	var reward_lbl := Label.new()
	reward_lbl.text = "+%d EXP  •  +%d Score  •  +50%% HP" % [exp_reward, score_reward]
	reward_lbl.size = Vector2(1000, 44)
	reward_lbl.position = Vector2(460, 522)
	reward_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reward_lbl.add_theme_font_size_override("font_size", 28)
	reward_lbl.add_theme_color_override("font_color", Color(0.4, 1.0, 0.55, 1.0))
	reward_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	reward_lbl.add_theme_constant_override("outline_size", 2)
	reward_lbl.modulate.a = 0.0
	cl.add_child(reward_lbl)
	var reward_t := reward_lbl.create_tween()
	reward_t.tween_interval(0.35)
	reward_t.tween_property(reward_lbl, "modulate:a", 1.0, 0.28)

	# Fade out then free
	var fade_t := cl.create_tween()
	fade_t.tween_interval(3.2)
	fade_t.tween_property(cl, "modulate:a", 0.0, 0.65)
	fade_t.tween_callback(cl.queue_free)

# Spawns staggered firework bursts across the play area.
func _spawn_fireworks(level: int) -> void:
	var count := mini(6 + level, 14)
	for i in count:
		var delay := randf_range(0.0, 2.5)
		var pos := Vector2(randf_range(180.0, 1740.0), randf_range(120.0, 850.0))
		get_tree().create_timer(delay).timeout.connect(_burst_firework.bind(pos))

# Single firework explosion: 16 colored dots fly outward and fade.
func _burst_firework(pos: Vector2) -> void:
	if not is_instance_valid(game_layer):
		return
	var container := Node2D.new()
	game_layer.add_child(container)
	container.z_index = 25
	container.global_position = pos
	var palette := [
		Color(1.0, 0.25, 0.2), Color(1.0, 0.85, 0.1),
		Color(0.25, 1.0, 0.5), Color(0.4, 0.65, 1.0),
		Color(1.0, 0.4,  1.0), Color(1.0, 0.6,  0.1),
	]
	var burst_color: Color = palette[randi() % palette.size()]
	var ray_count := 16
	for i in ray_count:
		var angle := (TAU / ray_count) * float(i) + randf_range(-0.12, 0.12)
		var dir := Vector2.from_angle(angle)
		var dot := ColorRect.new()
		dot.size = Vector2(6.0, 6.0)
		dot.color = burst_color
		dot.position = Vector2(-3.0, -3.0)
		container.add_child(dot)
		var dist := randf_range(52.0, 115.0)
		var t := dot.create_tween().set_parallel(true)
		t.tween_property(dot, "position", dir * dist + Vector2(-3.0, -3.0), 0.55) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(dot, "modulate:a", 0.0, 0.55).set_delay(0.22)
	container.create_tween().tween_callback(container.queue_free).set_delay(0.9)

# Returns 0.0–1.0: sum(current_hp) / sum(max_hp) across all avatars on the team.
func get_team_hp_ratio(team: int) -> float:
	var list := _avatars_a if team == 1 else _avatars_b
	var cur_sum := 0
	var max_sum := 0
	for av in list:
		if not is_instance_valid(av):
			continue
		cur_sum += int(av.get("current_hp", 0))
		var stats: Node = av.get("_avatar_stats") as Node
		if is_instance_valid(stats):
			max_sum += stats.get_max_hp()
		else:
			max_sum += 100
	if max_sum == 0:
		return 1.0
	return clampf(float(cur_sum) / float(max_sum), 0.0, 1.0)

# Returns combined current HP and max HP for the team (for label display).
func get_team_hp_totals(team: int) -> Vector2i:
	var list := _avatars_a if team == 1 else _avatars_b
	var cur_sum := 0
	var max_sum := 0
	for av in list:
		if not is_instance_valid(av):
			continue
		cur_sum += int(av.get("current_hp", 0))
		var stats: Node = av.get("_avatar_stats") as Node
		if is_instance_valid(stats):
			max_sum += stats.get_max_hp()
		else:
			max_sum += 100
	return Vector2i(cur_sum, max_sum)

# Boss attack: 30% to highest-level avatar, 70% split evenly among all.
func damage_team_boss_attack(team: int, total_damage: int) -> void:
	var list: Array = (_avatars_a if team == 1 else _avatars_b).duplicate()
	var alive: Array = []
	for av in list:
		if is_instance_valid(av) and av.get("_alive") and not av.get("_respawning"):
			alive.append(av)
	if alive.is_empty():
		return
	# Find highest-level avatar
	var highest: Node = null
	var highest_lv := 0
	for av in alive:
		var lv: int = PlayerStats.get_level(str(av.get("player_id", "")))
		if lv > highest_lv:
			highest_lv = lv
			highest = av
	var main_dmg := int(float(total_damage) * 0.3)
	var spread_dmg := int(float(total_damage) * 0.7 / float(alive.size()))
	for av in alive:
		var dmg := spread_dmg + (main_dmg if av == highest else 0)
		av.take_damage(maxi(1, dmg))

func _heal_all_half() -> void:
	for av in _avatars_a + _avatars_b:
		if is_instance_valid(av) and av.get("_alive") and not av.get("_respawning"):
			var max_hp: int = av._avatar_stats.get_max_hp() if av.get("_avatar_stats") else 100
			av.heal(max_hp / 2)

func _remove_announce_overlay() -> void:
	if is_instance_valid(_announce_overlay):
		_announce_overlay.queue_free()
	_announce_overlay = null

# ── TikTok avatar spawn from GameManager signal ───────────────────────────────

func _on_spawn_avatar_requested(data: Dictionary) -> void:
	if is_boss_phase:
		return
	var team := 1 if str(data.get("team", "")) == "team_a" else 2
	spawn_avatar(str(data.get("username", "")), team, str(data.get("avatar", "")))

# Applies donation EXP + HP from GIFT_TABLE to every alive avatar on the team.
# Used by the debug panel "Donation Scale (All)" buttons.
func debug_donation_all(team: int, gift_name: String) -> void:
	var entry: Dictionary = GameManager.GIFT_TABLE.get(gift_name, {})
	if entry.is_empty():
		return
	var hp: int = entry.get("hp", 0)
	var exp: int = entry.get("exp", 0)
	if hp > 0:
		heal_team(team, hp)
	if exp > 0:
		var list := _avatars_a if team == 1 else _avatars_b
		for av in list:
			if is_instance_valid(av) and av.get("player_id") != "":
				PlayerStats.add_exp(str(av.get("player_id")), exp, "donate")

func _end_game() -> void:
	game_active = false
	var winner := 0
	if score_a > score_b:
		winner = 1
		timer_label.text = "TEAM A WIN!"
		timer_label.add_theme_color_override("font_color", Color(0.3, 0.6, 1.0, 1.0))
	elif score_b > score_a:
		winner = 2
		timer_label.text = "TEAM B WIN!"
		timer_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.08, 1.0))
	else:
		timer_label.text = "DRAW!"
		timer_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9, 1.0))
	emit_signal("game_over", winner)
