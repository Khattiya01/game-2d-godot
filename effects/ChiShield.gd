extends Node2D

const DURATION: float = 5.0
const FADE_TIME: float = 0.5
const BASE_RADIUS: float = 22.0
const CIRCLE_SEGMENTS: int = 32
const PULSE_SCALE_MAX: float = 1.06

# PNG sprite — place chi_shield.png at res://assets/chi_shield.png
# Adjust SPRITE_SCALE if your PNG is not 512×512 (scale = desired_diameter / png_size)
const SPRITE_SCALE: float = 0.09
const SPRITE_ROT_SPEED: float = 18.0   # degrees CW per second
const ORB_ORBIT_SPEED: float = 65.0    # degrees per second, 4 chi orbs

# Wudang White Dragon: cyan-white energy ring
const GLOW_COLOR := Color(0.45, 0.95, 1.00, 0.24)
const CORE_COLOR := Color(0.88, 1.00, 1.00, 0.90)
const SFX := preload("res://assets/sounds/deflector_shield_01.wav")

var _broken: bool = false
var _active: bool = false
var _pulse_tween: Tween = null
var _avatar: Node = null
var _sprite: Sprite2D = null
var _orbs: Array = []
var _orb_angle: float = 0.0
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
	var try_paths := ["res://effects/textures/chi_shield.png", "res://assets/chi_shield.png", "res://chi_shield.png"]
	for p in try_paths:
		if ResourceLoader.exists(p):
			tex = load(p) as Texture2D
			break
	if tex == null:
		push_warning("ChiShield: chi_shield.png not found — tried: %s" % ", ".join(try_paths))
		return
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
	_sprite.z_index = 2
	# Normal blend so sprite renders with full opacity — no additive wash
	_sprite.modulate = Color(0.90, 1.0, 1.0, 1.0)  # slight cyan tint, fully opaque
	add_child(_sprite)

func _process(delta: float) -> void:
	if not _active:
		return
	# Slow CW dragon rotation
	if is_instance_valid(_sprite):
		_sprite.rotation_degrees += SPRITE_ROT_SPEED * delta
	# 4 chi orbs orbiting at 1.35× radius
	_orb_angle += ORB_ORBIT_SPEED * delta
	for i in _orbs.size():
		var orb: Node2D = _orbs[i]
		if is_instance_valid(orb):
			var a := deg_to_rad(_orb_angle + 90.0 * float(i))
			orb.position = Vector2.from_angle(a) * BASE_RADIUS * 1.35

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
	_build_chi_orbs()
	_build_halo()
	_spawn_activate_burst()
	_spawn_activate_particles()
	_active = true
	# Sprite scale-in
	if is_instance_valid(_sprite):
		_sprite.scale = Vector2.ZERO
		var si := create_tween()
		si.tween_property(_sprite, "scale", Vector2(SPRITE_SCALE, SPRITE_SCALE), 0.30) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(self, "scale", Vector2.ONE * PULSE_SCALE_MAX, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "scale", Vector2.ONE, 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	get_tree().create_timer(DURATION - FADE_TIME).timeout.connect(func():
		if not is_instance_valid(self) or _broken:
			return
		_expire()
	)

# Absorbs 1 hit fully. killer_id ignored (no reflect for Team A).
func absorb_damage(incoming: int, _killer_id: String = "") -> int:
	if _broken:
		return incoming
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
	_spawn_break_flash()
	var t := create_tween()
	t.tween_property(self, "scale", Vector2.ONE * 2.2, 0.12) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "modulate:a", 0.0, 0.22)
	t.tween_callback(func():
		if is_instance_valid(self):
			queue_free()
	)

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

func _build_circle(radius: float) -> void:
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
	flash_polygon.color = Color(0.72, 1.00, 1.00, 0.28)
	flash_polygon.modulate.a = 0.45
	create_tween().tween_property(flash_polygon, "modulate:a", 0.0, 0.40)

func _build_chi_orbs() -> void:
	# 4 small glowing dots that orbit the shield ring
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for _i in 4:
		var orb := Polygon2D.new()
		add_child(orb)
		orb.z_index = 6
		orb.material = mat
		orb.color = Color(1.0, 0.95, 0.55, 1.0)  # gold-white chi orb
		var pts: PackedVector2Array = []
		for j in 8:
			pts.append(Vector2.from_angle(TAU * float(j) / 8.0) * 3.2)
		orb.polygon = pts
		_orbs.append(orb)

func _build_halo() -> void:
	# Persistent white-gold soft glow polygon — visual cue shield is active
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_halo = Polygon2D.new()
	_halo.z_index = 0
	_halo.material = mat
	_halo.color = Color(1.0, 0.95, 0.72, 0.16)
	var pts: PackedVector2Array = []
	for i in 32:
		pts.append(Vector2.from_angle(TAU * float(i) / 32.0) * BASE_RADIUS * 1.55)
	_halo.polygon = pts
	add_child(_halo)
	_halo_tween = create_tween().set_loops()
	_halo_tween.tween_property(_halo, "modulate:a", 0.28, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_halo_tween.tween_property(_halo, "modulate:a", 0.07, 0.9) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

func _spawn_break_flash() -> void:
	# White chi particle burst on break
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.4, Color(0.85, 0.95, 1.0, 0.7))
	grad.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.spread = 180.0
	pm.initial_velocity_min = 55.0
	pm.initial_velocity_max = 120.0
	pm.gravity = Vector3(0.0, -22.0, 0.0)
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.color_ramp = cramp
	var p := GPUParticles2D.new()
	add_child(p)
	p.z_index = 8
	p.texture = _make_circle_tex()
	p.process_material = pm
	p.amount = 30
	p.lifetime = 0.55
	p.one_shot = true
	p.explosiveness = 0.95
	p.emitting = true
	var pmat := CanvasItemMaterial.new()
	pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = pmat
	var pt := create_tween()
	pt.tween_interval(1.0)
	pt.tween_callback(p.queue_free)

func _spawn_activate_burst() -> void:
	# Single cyan ring that expands and vanishes — does NOT linger
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring := _make_ring(BASE_RADIUS, 18.0, Color(0.55, 0.98, 1.00, 0.70), mat)
	var t := ring.create_tween().set_parallel(true)
	t.tween_property(ring, "scale", Vector2(2.6, 2.6), 0.32) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ring, "modulate:a", 0.0, 0.32)
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
	grad.set_color(0, Color(0.72, 1.00, 1.00, 0.95))
	grad.add_point(0.5, Color(0.55, 0.90, 1.00, 0.55))
	grad.set_color(1, Color(1.00, 1.00, 1.00, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 32.0
	pm.initial_velocity_max = 88.0
	pm.gravity = Vector3(0.0, -14.0, 0.0)  # chi floats upward
	pm.scale_min = 0.4
	pm.scale_max = 1.4
	pm.color_ramp = cramp
	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.z_index = 5
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 28
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 0.78
	particles.emitting = true
	var pmat := CanvasItemMaterial.new()
	pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = pmat
	var pt := create_tween()
	pt.tween_interval(1.3)
	pt.tween_callback(particles.queue_free)

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
