extends Node2D

const TEAM_COLOR: Dictionary = {
	1: Color(0.05, 0.4, 1.0, 1.0),
	2: Color(1.0, 0.12, 0.05, 1.0),
}
const TEAM_SHADOW_COLOR: Dictionary = {
	1: Color(0.0, 0.3, 1.0, 0.6),
	2: Color(1.0, 0.05, 0.0, 0.6),
}
const MAX_HP: int = 1000  # Fallback only; runtime uses PlayerStats level-based HP
const BASE_SCALE: float = 0.22
const ATTACK_INTERVAL: float = 1.5
const SPEED_MIN: float = 90.0
const SPEED_MAX: float = 200.0
const AVATAR_RADIUS: float = 14.0
const RESPAWN_TIME: float = 3.0

const DamageNumberScene := preload("res://effects/DamageNumber.tscn")
const AvatarStatsScript = preload("res://scenes/AvatarStats.gd")
const CircularBarsScript = preload("res://scenes/CircularBars.gd")

signal avatar_died(avatar: Node, team: int)

@onready var http_request: HTTPRequest = $HTTPRequest
@onready var float_pivot: Node2D = $FloatPivot
@onready var glow_sprite: Sprite2D = $FloatPivot/GlowSprite
@onready var avatar_sprite: Sprite2D = $FloatPivot/AvatarSprite
@onready var username_label: Label = $UsernameLabel
@onready var lv_label: Label = $LvLabel

var _team: int = 1
var _float_time: float = 0.0
var _float_speed: float = 1.0
var _float_amp: float = 6.0
var _floating: bool = false
var _alive: bool = true
var _attack_timer: float = 0.0
var _is_attacking: bool = false
var _arena_ref: Node = null
var current_hp: int = MAX_HP
var _velocity: Vector2 = Vector2.ZERO
var _base_speed: float = 0.0
var _zone_rect: Rect2 = Rect2()

var player_id: String = ""
var _last_killer_id: String = ""
var _team_color: Color = Color.WHITE
var _avatar_stats: Node = null
var _circular_bars: Node2D = null
var _respawning: bool = false
var _respawn_timer: float = 0.0
var _countdown_label: Label = null
var _boss_phase: bool = false
var _stunned: bool = false

func _ready() -> void:
	http_request.request_completed.connect(_on_request_completed)
	glow_sprite.material = glow_sprite.material.duplicate()
	_avatar_stats = AvatarStatsScript.new()
	add_child(_avatar_stats)
	_avatar_stats.level_up_visual.connect(_on_level_up_visual)
	_avatar_stats.exp_updated.connect(_on_exp_updated)
	_circular_bars = CircularBarsScript.new()
	add_child(_circular_bars)
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.3) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func setup(p_username: String, p_team: int, avatar_url: String, p_arena: Node = null) -> void:
	player_id = p_username
	PlayerStats.register_player(player_id)
	_last_killer_id = ""
	_team = p_team
	_arena_ref = p_arena
	_alive = true
	_respawning = false
	_attack_timer = randf_range(0.5, ATTACK_INTERVAL)

	var color: Color = TEAM_COLOR.get(p_team, TEAM_COLOR[1])
	var shadow: Color = TEAM_SHADOW_COLOR.get(p_team, TEAM_SHADOW_COLOR[1])
	_team_color = color

	username_label.text = p_username
	username_label.add_theme_color_override("font_color", color)
	username_label.add_theme_color_override("font_shadow_color", shadow)
	glow_sprite.material.set_shader_parameter("glow_color", color)

	_avatar_stats.initialize(player_id)
	current_hp = _avatar_stats.get_max_hp()
	float_pivot.scale = Vector2.ONE * BASE_SCALE * _avatar_stats.get_size_scale()
	lv_label.text = "Lv.%d" % _avatar_stats.current_level
	_refresh_hp_bar()
	_refresh_exp_bar()

	_float_speed = randf_range(0.55, 1.3)
	_float_amp = randf_range(4.0, 8.0)
	_float_time = randf_range(0.0, TAU)
	_floating = true

	if p_arena:
		_zone_rect = p_arena.zone_a if p_team == 1 else p_arena.zone_b
	var angle := randf_range(0.0, TAU)
	_base_speed = randf_range(SPEED_MIN, SPEED_MAX)
	_velocity = Vector2(cos(angle), sin(angle)) * _base_speed

	if avatar_url != "":
		http_request.request(avatar_url)
	else:
		avatar_sprite.texture = _make_mock_texture(color)

func set_boss_phase(active: bool) -> void:
	_boss_phase = active
	if active:
		_velocity = Vector2.ZERO  # Freeze in place during boss phase
	else:
		var angle := randf_range(0.0, TAU)
		_velocity = Vector2(cos(angle), sin(angle)) * _base_speed

func heal(amount: int) -> void:
	if not _alive or _respawning:
		return
	var max_hp: int = _avatar_stats.get_max_hp() if _avatar_stats else MAX_HP
	current_hp = mini(max_hp, current_hp + amount)
	_refresh_hp_bar()
	_spawn_heal_number(amount)
	if is_instance_valid(_circular_bars):
		_circular_bars.flash_hp_green()
	# Green glow ring flash
	var glow_tween := create_tween()
	glow_tween.tween_method(_set_glow_color, _team_color, Color(0.1, 1.0, 0.3, 1.0), 0.15)
	glow_tween.tween_interval(0.35)
	glow_tween.tween_method(_set_glow_color, Color(0.1, 1.0, 0.3, 1.0), _team_color, 0.45)

func stun(duration: float) -> void:
	if not _alive or _respawning:
		return
	_stunned = true
	_velocity = Vector2.ZERO
	_is_attacking = false
	await get_tree().create_timer(duration).timeout
	_stunned = false
	if is_instance_valid(self) and _alive and not _respawning:
		var angle := randf_range(0.0, TAU)
		_velocity = Vector2(cos(angle), sin(angle)) * _base_speed

func knockback(force: Vector2) -> void:
	if _respawning:
		return
	# Redirect direction only — speed stays at _base_speed
	_velocity = (_velocity + force * 0.5).normalized() * _base_speed

func take_damage(amount: int, killer_id: String = "") -> void:
	if not _alive:
		return
	# Let active shields absorb damage first (innermost stack first)
	var dmg := amount
	for child in get_children():
		if dmg <= 0:
			break
		if child.is_in_group("shield_bubble") and child.has_method("absorb_damage"):
			dmg = child.absorb_damage(dmg)
	if dmg <= 0:
		return
	_last_killer_id = killer_id
	current_hp = maxi(0, current_hp - dmg)
	_refresh_hp_bar()
	_spawn_damage_number(dmg)
	if current_hp == 0:
		die()

func die() -> void:
	if not _alive:
		return
	_alive = false
	_is_attacking = false
	if is_instance_valid(_arena_ref):
		var reward: int = PlayerStats.get_stats(player_id).get("kill_reward_exp", 0)
		if reward > 0:
			_arena_ref.spawn_exp_gain_text(global_position, reward)
		_arena_ref.add_score(3 - _team, 1)
	PlayerStats.on_kill(_last_killer_id, player_id)
	# Player kill (not boss) charges the killer's team ultimate meter
	if _last_killer_id != "" and _last_killer_id != "boss":
		var killer_team_key := "team_a" if (3 - _team) == 1 else "team_b"
		UltimateCharger.add_charge(killer_team_key, 2.0)
	_start_respawn()

func _process(delta: float) -> void:
	if _floating:
		_float_time += delta * _float_speed
		float_pivot.position = Vector2(
			sin(_float_time * 0.6 + 1.0) * _float_amp * 0.4,
			sin(_float_time) * _float_amp
		)
	if is_instance_valid(_circular_bars):
		_circular_bars.position = float_pivot.position
	if _respawning:
		_respawn_timer -= delta
		_update_respawn_countdown()
		if _respawn_timer <= 0.0:
			_finish_respawn()
		return  # Frozen during respawn — no physics, no attack
	if _zone_rect.size != Vector2.ZERO and not _boss_phase and not _stunned:
		_update_physics(delta)
	if _alive and _arena_ref and (_arena_ref.game_active or _arena_ref.is_boss_phase):
		if not _is_attacking and not _stunned:
			_attack_timer -= delta
			if _attack_timer <= 0.0:
				_do_attack()

func _update_physics(delta: float) -> void:
	position += _velocity * delta
	var r := AVATAR_RADIUS
	if position.x - r < _zone_rect.position.x:
		position.x = _zone_rect.position.x + r
		_velocity.x = abs(_velocity.x)
	elif position.x + r > _zone_rect.end.x:
		position.x = _zone_rect.end.x - r
		_velocity.x = -abs(_velocity.x)
	if position.y - r < _zone_rect.position.y:
		position.y = _zone_rect.position.y + r
		_velocity.y = abs(_velocity.y)
	elif position.y + r > _zone_rect.end.y:
		position.y = _zone_rect.end.y - r
		_velocity.y = -abs(_velocity.y)
	# Re-normalize to constant base speed after all bounces
	if _velocity.length_squared() > 0.0:
		_velocity = _velocity.normalized() * _base_speed

func _do_attack() -> void:
	var enemy: Node = _arena_ref.get_nearest_enemy(global_position, _team)
	if not enemy or not is_instance_valid(enemy):
		# No enemy — fire basic shot at zone center, score +1
		_attack_timer = ATTACK_INTERVAL
		var target_pos: Vector2 = _arena_ref.get_zone_center(3 - _team)
		_arena_ref.spawn_attack_effect(global_position, target_pos, null)
		_arena_ref.add_score(_team, 1)
		return

	_is_attacking = true
	var dmg_mult: float = _arena_ref.get_attack_mult(_team)
	var base_dmg: int = int(_avatar_stats.get_damage()) if _avatar_stats else 10
	# During boss phase use basic attacks only (no chain/laser to avoid targeting allies)
	var roll: int
	if _arena_ref.is_boss_phase:
		roll = 0
	elif _arena_ref.debug_attack_mode >= 0:
		roll = _arena_ref.debug_attack_mode
	else:
		roll = randi() % 6
	match roll:
		0:
			_arena_ref.spawn_attack_effect(global_position, enemy.global_position, enemy, on_attack_done, dmg_mult, player_id, base_dmg)
		1:
			_arena_ref.spawn_laser_attack(self, enemy, on_attack_done, dmg_mult, base_dmg)
		2:
			_arena_ref.spawn_lightning_attack(self, enemy, _team, on_attack_done, dmg_mult, base_dmg)
		3:
			_arena_ref.spawn_shield_bubble(self, on_attack_done)
		4:
			_arena_ref.spawn_spikes_attack(self, _team, on_attack_done, dmg_mult, base_dmg)
		5:
			_arena_ref.spawn_stun_projectile_attack(self, enemy, on_attack_done, dmg_mult, base_dmg)

func on_attack_done() -> void:
	if not _alive:
		return
	_is_attacking = false
	_attack_timer = ATTACK_INTERVAL

# ── Respawn system ────────────────────────────────────────────────────────────

func _start_respawn() -> void:
	_respawning = true
	_velocity = Vector2.ZERO
	# Remove all active shield layers on death
	for child in get_children():
		if child.is_in_group("shield_bubble"):
			child.queue_free()
	# Sync visual to the new (lower) level immediately
	var new_level := PlayerStats.get_level(player_id)
	_avatar_stats.current_level = new_level
	# Red flash → semi-transparent
	modulate = Color(1.0, 0.25, 0.25, 1.0)
	var fade_tween := create_tween()
	fade_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.4), 0.35)
	# Shrink size to new level
	var new_scale: Vector2 = Vector2.ONE * BASE_SCALE * _avatar_stats.get_size_scale()
	var sz_tween := create_tween()
	sz_tween.tween_property(float_pivot, "scale", new_scale, 0.35) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Teleport to random position in own zone
	if _zone_rect.size != Vector2.ZERO:
		position = Vector2(
			randf_range(_zone_rect.position.x + 64.0, _zone_rect.end.x - 64.0),
			randf_range(_zone_rect.position.y + 64.0, _zone_rect.end.y - 64.0)
		)
	# Create countdown label
	_respawn_timer = RESPAWN_TIME
	_countdown_label = Label.new()
	add_child(_countdown_label)
	_countdown_label.position = Vector2(-24, -40)
	_countdown_label.size = Vector2(48, 16)
	_countdown_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_countdown_label.add_theme_font_size_override("font_size", 11)
	_countdown_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.55, 0.9))
	_countdown_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	_countdown_label.add_theme_constant_override("outline_size", 1)

func _update_respawn_countdown() -> void:
	if not is_instance_valid(_countdown_label):
		return
	var secs := int(ceil(_respawn_timer))
	_countdown_label.text = "%d..." % secs if secs > 0 else "Ready!"

func _finish_respawn() -> void:
	_respawning = false
	_alive = true
	if is_instance_valid(_countdown_label):
		_countdown_label.queue_free()
	_countdown_label = null
	# Restore HP to full at current level
	current_hp = _avatar_stats.get_max_hp()
	_refresh_hp_bar()
	_refresh_exp_bar()
	# Resume movement
	var angle := randf_range(0.0, TAU)
	_velocity = Vector2(cos(angle), sin(angle)) * _base_speed
	_attack_timer = randf_range(0.5, ATTACK_INTERVAL)
	# Fade to full opacity
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.3)
	print("[PlayerAvatar] %s respawned → Lv%d  HP=%d" % [
		player_id, PlayerStats.get_level(player_id), current_hp
	])

# ── Level-up visual ───────────────────────────────────────────────────────────

func _on_level_up_visual(new_level: int) -> void:
	current_hp = _avatar_stats.get_max_hp()
	lv_label.text = "Lv.%d" % new_level
	_refresh_hp_bar()
	_refresh_exp_bar()
	var target_scale: Vector2 = Vector2.ONE * BASE_SCALE * _avatar_stats.get_size_scale()
	var sz_tween := create_tween()
	sz_tween.tween_property(float_pivot, "scale", target_scale, 0.4) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var glow_tween := create_tween()
	glow_tween.tween_method(_set_glow_color, _team_color, Color(0.1, 1.0, 0.3, 1.0), 0.15)
	glow_tween.tween_interval(0.4)
	glow_tween.tween_method(_set_glow_color, Color(0.1, 1.0, 0.3, 1.0), _team_color, 0.5)
	print("[PlayerAvatar] %s ↑ Lv%d  HP=%d" % [player_id, new_level, current_hp])

func _on_exp_updated() -> void:
	_refresh_exp_bar()

func _set_glow_color(c: Color) -> void:
	if is_instance_valid(glow_sprite):
		glow_sprite.material.set_shader_parameter("glow_color", c)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _spawn_heal_number(amount: int) -> void:
	if not _arena_ref or not is_instance_valid(_arena_ref):
		return
	var container := Node2D.new()
	_arena_ref.game_layer.add_child(container)
	container.z_index = 10
	container.global_position = global_position + Vector2(randf_range(-8.0, 8.0), -20.0)
	var label := Label.new()
	container.add_child(label)
	label.text = "+%d HP" % amount
	label.position = Vector2(-16, 0)
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.45, 1.0))
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 1.0))
	label.add_theme_constant_override("outline_size", 2)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(container, "global_position:y", container.global_position.y - 35.0, 0.9)
	tween.tween_property(container, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(container.queue_free)

func _spawn_damage_number(amount: int) -> void:
	if not _arena_ref or not is_instance_valid(_arena_ref):
		return
	var dmg_num := DamageNumberScene.instantiate()
	_arena_ref.game_layer.add_child(dmg_num)
	dmg_num.global_position = global_position + Vector2(randf_range(-8.0, 8.0), -20.0)
	dmg_num.show_number(amount)

func _refresh_hp_bar() -> void:
	if not is_instance_valid(_circular_bars):
		return
	var max_hp: int = _avatar_stats.get_max_hp() if _avatar_stats else MAX_HP
	_circular_bars.set_hp(float(current_hp) / float(max_hp))

func _refresh_exp_bar() -> void:
	if not is_instance_valid(_circular_bars) or not _avatar_stats:
		return
	_circular_bars.set_exp(_avatar_stats.get_exp_progress())

func _make_mock_texture(team_color: Color) -> ImageTexture:
	const SIZE := 128
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGBA8)
	var center := Vector2(SIZE * 0.5, SIZE * 0.5)
	var radius := SIZE * 0.46
	for y in SIZE:
		for x in SIZE:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(center)
			var alpha := clampf(1.0 - (d - radius + 2.0) / 2.0, 0.0, 1.0)
			if alpha > 0.0:
				var bright := lerpf(1.0, 0.65, d / radius)
				img.set_pixel(x, y, Color(
					team_color.r * bright,
					team_color.g * bright,
					team_color.b * bright,
					alpha
				))
	return ImageTexture.create_from_image(img)

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var image := Image.new()
	var err := image.load_jpg_from_buffer(body)
	if err != OK:
		err = image.load_png_from_buffer(body)
	if err != OK:
		return
	avatar_sprite.texture = ImageTexture.create_from_image(image)
