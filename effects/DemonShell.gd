extends Node2D

const DURATION: float = 5.0
const FADE_TIME: float = 0.5
const BASE_RADIUS: float = 22.0
const CIRCLE_SEGMENTS: int = 32
const PULSE_SCALE_MAX: float = 1.05
const SPIKE_COUNT: int = 8
const SPIKE_LEN: float = 11.0
const REFLECT_PERCENT: float = 0.20

# PNG sprite — place demon_shell.png at res://assets/demon_shell.png
# Adjust SPRITE_SCALE if your PNG is not 512×512 (scale = desired_diameter / png_size)
const SPRITE_SCALE: float = 0.09
const SPRITE_ROT_SPEED: float = -12.0  # CCW (negative) degrees per second
const SHARD_ORBIT_SPEED: float = -50.0 # CCW degrees per second, 3 dark shards
const JITTER_INTERVAL_MIN: float = 1.2
const JITTER_INTERVAL_MAX: float = 2.0

# Demon Dragon: blood-purple aura + deep crimson core
const GLOW_COLOR := Color(0.45, 0.0, 0.70, 0.28)
const CORE_COLOR := Color(0.88, 0.05, 0.15, 0.90)
const SFX := preload("res://assets/sounds/deflector_shield_01.wav")

var _broken: bool = false
var _active: bool = false
var _pulse_tween: Tween = null
var _avatar: Node = null
var _sprite: Sprite2D = null
var _shards: Array = []
var _shard_angle: float = 0.0
var _jitter_timer: float = 1.5
var _halo: Polygon2D = null
var _halo_tween: Tween = null

@onready var glow_line: Line2D = $GlowLine
@onready var core_line: Line2D = $CoreLine
@onready var flash_polygon: Polygon2D = $FlashPolygon

func _ready() -> void:
	add_to_group("shield_bubble")
	_setup_sprite()

func _setup_sprite() -> void:
	var tex: Texture2D = null
	var try_paths := ["res://effects/textures/demon_shell.png", "res://assets/demon_shell.png", "res://demon_shell.png"]
	for p in try_paths:
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D
			break
	if tex == null:
		push_warning("DemonShell: demon_shell.png not found — tried: %s" % ", ".join(try_paths))
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.z_index = 2
	# Normal blend so dark dragon PNG shows actual black colors — no additive wash
	_sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)  # pure white tint = original PNG colors
	add_child(_sprite)

func _process(delta: float) -> void:
	if not _active:
		return
	if is_instance_valid(_sprite):
		_sprite.rotation_degrees += SPRITE_ROT_SPEED * delta
		# Periodic menacing jitter — snap ±8° randomly
		_jitter_timer -= delta
		if _jitter_timer <= 0.0:
			_sprite.rotation_degrees += randf_range(-8.0, 8.0)
			_jitter_timer = randf_range(JITTER_INTERVAL_MIN, JITTER_INTERVAL_MAX)
	# 3 dark shards orbit CCW at 1.4× radius, pointing outward
	_shard_angle += SHARD_ORBIT_SPEED * delta
	for i in _shards.size():
		var shard: Node2D = _shards[i]
		if is_instance_valid(shard):
			var a := deg_to_rad(_shard_angle + 120.0 * float(i))
			shard.position = Vector2.from_angle(a) * BASE_RADIUS * 1.4
			shard.rotation = a + PI * 0.5

func fire(data: Dictionary) -> void:
	_avatar = data.get("avatar")
	if not is_instance_valid(_avatar):
		queue_free()
		return
	position = Vector2.ZERO
	modulate.a = 1.0
	_play_sound()
	# Hide tscn Line2D nodes — sprite is the main visual
	glow_line.visible = false
	core_line.visible = false
	flash_polygon.visible = false
	_build_dark_shards()
	_build_halo()
	_spawn_activate_burst()
	_spawn_activate_particles()
	_active = true
	# Sprite slam-in from zero
	if is_instance_valid(_sprite):
		_sprite.scale = Vector2.ZERO
		var si := create_tween()
		si.tween_property(_sprite, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.22) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * PULSE_SCALE_MAX, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(DURATION - FADE_TIME).timeout.connect(func():
		if not is_instance_valid(self) or _broken:
			return
		_expire()
	)

# Absorbs 1 hit + reflects 20% damage back to attacker (deferred).
func absorb_damage(incoming: int, killer_id: String = "") -> int:
	if _broken:
		return incoming
	var reflect := int(float(incoming) * REFLECT_PERCENT)
	if reflect > 0 and killer_id != "" and is_instance_valid(_avatar):
		var arena: Node = _avatar.get("_arena_ref")
		if is_instance_valid(arena):
			var attacker: Node = arena._find_avatar_by_id(killer_id)
			if is_instance_valid(attacker):
				attacker.call_deferred("take_damage", reflect, "demon_shell_reflect")
	# Flash blood-red on the sprite before shattering
	if is_instance_valid(_sprite):
		_sprite.modulate = Color(1.0, 0.08, 0.08, 1.0)
	_break()
	return 0

func _break() -> void:
	if _broken:
		return
	_broken = true
	_active = false
	if _pulse_tween:
		_pulse_tween.kill()
	if _halo_tween:
		_halo_tween.kill()
	_spawn_break_sequence()

func _expire() -> void:
	if _broken:
		return
	_active = false
	if _pulse_tween:
		_pulse_tween.kill()
	if _halo_tween:
		_halo_tween.kill()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
	fade.tween_callback(func():
		if is_instance_valid(self):
			queue_free()
	)

func _build_shell(radius: float) -> void:
	glow_line.default_color = GLOW_COLOR
	core_line.default_color = CORE_COLOR
	var pts: PackedVector2Array = []
	for i in CIRCLE_SEGMENTS + 1:
		pts.append(Vector2.from_angle(TAU * float(i) / CIRCLE_SEGMENTS) * radius)
	glow_line.points = pts
	core_line.points = pts
	var flash_pts: PackedVector2Array = []
	for i in 24:
		flash_pts.append(Vector2.from_angle(TAU * float(i) / 24.0) * (radius * 0.85))
	flash_polygon.polygon = flash_pts
	flash_polygon.color = Color(0.58, 0.0, 0.06, 0.35)
	flash_polygon.modulate.a = 0.55
	create_tween().tween_property(flash_polygon, "modulate:a", 0.0, 0.40)
	_build_spikes(radius)

func _build_spikes(radius: float) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in SPIKE_COUNT:
		var angle := TAU * float(i) / float(SPIKE_COUNT)
		var base_c := Vector2.from_angle(angle) * radius
		var perp := Vector2.from_angle(angle + PI * 0.5)
		var tip := base_c + Vector2.from_angle(angle) * SPIKE_LEN
		var b0 := base_c - perp * 3.5
		var b1 := base_c + perp * 3.5
		var spike := Polygon2D.new()
		add_child(spike)
		spike.z_index = 3
		spike.material = mat
		spike.color = Color(0.82, 0.08, 0.05, 0.82)
		spike.polygon = PackedVector2Array([b0, tip, b1])

func _build_dark_shards() -> void:
	# 3 purple diamond shards orbiting CCW
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for _i in 3:
		var shard := Polygon2D.new()
		add_child(shard)
		shard.z_index = 6
		shard.material = mat
		shard.color = Color(0.72, 0.0, 1.0, 0.92)  # vivid violet shard
		shard.polygon = PackedVector2Array([
			Vector2(0.0, -6.5),
			Vector2(3.2,  0.0),
			Vector2(0.0,  5.0),
			Vector2(-3.2, 0.0),
		])
		_shards.append(shard)

func _build_halo() -> void:
	# Persistent dark-purple void glow — demon aura cue that shield is active
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo = Polygon2D.new()
	_halo.z_index = 0
	_halo.material = mat
	_halo.color = Color(0.42, 0.0, 0.68, 0.18)
	var pts: PackedVector2Array = []
	for i in 32:
		pts.append(Vector2.from_angle(TAU * float(i) / 32.0) * BASE_RADIUS * 1.60)
	_halo.polygon = pts
	add_child(_halo)
	_halo_tween = create_tween().set_loops()
	_halo_tween.tween_property(_halo, "modulate:a", 0.32, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_halo_tween.tween_property(_halo, "modulate:a", 0.06, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_activate_burst() -> void:
	# Single blood-red ring that expands and vanishes — does NOT linger
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := _make_ring(BASE_RADIUS, 16.0, Color(0.85, 0.06, 0.0, 0.68), mat)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.30) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.30)
	t.set_parallel(false)
	t.tween_callback(ring.queue_free)

func _make_ring(radius: float, width: float, color: Color, mat: Material) -> Line2D:
	var ring := Line2D.new()
	add_child(ring)
	ring.z_index = 4
	ring.material = mat
	ring.width = width
	ring.default_color = color
	ring.antialiased = true
	for i in 13:
		ring.add_point(Vector2.from_angle(TAU * float(i) / 12.0) * radius)
	return ring

func _spawn_activate_particles() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.88, 0.08, 0.10, 0.90))
	grad.add_point(0.5, Color(0.50, 0.0, 0.60, 0.55))
	grad.set_color(1, Color(0.28, 0.0, 0.0, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, 1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 26.0
	pm.initial_velocity_max = 70.0
	pm.gravity = Vector3(0.0, 14.0, 0.0)  # dark energy falls downward
	pm.scale_min = 0.4
	pm.scale_max = 1.3
	pm.color_ramp = cramp
	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.z_index = 5
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 22
	particles.lifetime = 0.50
	particles.one_shot = true
	particles.explosiveness = 0.80
	particles.emitting = true
	var pmat := CanvasItemMaterial.new()
	pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = pmat
	var pt := create_tween()
	pt.tween_interval(1.0)
	pt.tween_callback(particles.queue_free)

func _spawn_break_sequence() -> void:
	# Phase 1: implosion — dragon shell collapses inward
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(0.30, 0.30), 0.14) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	# Phase 2: explosion — demonic energy erupts outward
	t.tween_callback(func():
		if not is_instance_valid(self):
			return
		# Purple void particle burst
		var grad := Gradient.new()
		grad.set_color(0, Color(0.70, 0.0, 1.0, 1.0))
		grad.add_point(0.5, Color(0.40, 0.0, 0.65, 0.6))
		grad.set_color(1, Color(0.15, 0.0, 0.25, 0.0))
		var cramp := GradientTexture1D.new()
		cramp.gradient = grad
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		pm.spread = 180.0
		pm.initial_velocity_min = 50.0
		pm.initial_velocity_max = 115.0
		pm.gravity = Vector3(0.0, 20.0, 0.0)
		pm.scale_min = 0.5
		pm.scale_max = 1.5
		pm.color_ramp = cramp
		var p := GPUParticles2D.new()
		add_child(p)
		p.z_index = 8
		p.texture = _make_circle_tex()
		p.process_material = pm
		p.amount = 28
		p.lifetime = 0.60
		p.one_shot = true
		p.explosiveness = 0.95
		p.emitting = true
		var pmat := CanvasItemMaterial.new()
		pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = pmat
		var pt := create_tween()
		pt.tween_interval(1.0)
		pt.tween_callback(p.queue_free)
	)
	t.tween_property(self, "scale", Vector2(2.4, 2.4), 0.20) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.22)
	t.tween_callback(func():
		if is_instance_valid(self):
			queue_free()
	)

func _play_sound() -> void:
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = SFX
	player.play()
	player.finished.connect(player.queue_free)

func _make_circle_tex() -> ImageTexture:
	const S := 8
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c := Vector2(S * 0.5, S * 0.5)
	for y in S:
		for x in S:
			var a := clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(c) / (S * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
