extends Node2D

# Holy-light shockwave for Team A ultimate impact — white-gold spiral rings + light rays.

@onready var ring1: Line2D = $SpiralRings/Ring1
@onready var ring2: Line2D = $SpiralRings/Ring2
@onready var ring3: Line2D = $SpiralRings/Ring3
@onready var light_rays: Node2D = $LightRays
@onready var particle_burst: GPUParticles2D = $ParticleBurst
@onready var glow_rect: ColorRect = $CenterGlow/GlowRect
@onready var sfx: AudioStreamPlayer = $ExplosionSFX

var _add_mat: CanvasItemMaterial

func _ready() -> void:
	_add_mat = CanvasItemMaterial.new()
	_add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

func play(center: Vector2) -> void:
	global_position = center
	sfx.play()
	particle_burst.emitting = true
	_spawn_rays()
	_animate_ring(ring1, 0.0,  1.8, 280.0,  1.0)
	_animate_ring(ring2, 0.08, 1.8, 260.0, -1.0)
	_animate_ring(ring3, 0.16, 1.8, 240.0,  1.0)
	_animate_glow()
	await get_tree().create_timer(2.2, true).timeout
	queue_free()

func _animate_ring(ring: Line2D, delay: float, duration: float, max_r: float, spin_dir: float) -> void:
	ring.points = _spiral_pts(0.1, 0.1, 0.0, 0.01, 32)
	if delay > 0.0:
		await get_tree().create_timer(delay, true).timeout
	var tween := create_tween()
	tween.tween_method(_ring_updater(ring, max_r, spin_dir), 0.0, 1.0, duration)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)

func _ring_updater(ring: Line2D, max_r: float, spin_dir: float) -> Callable:
	# Returns a closure used by tween_method to redraw the spiral each frame.
	return func(t: float) -> void:
		ring.points = _spiral_pts(
			maxf(0.1, t * max_r * 0.25), maxf(0.1, t * max_r),
			spin_dir * t * PI, spin_dir * t * PI + TAU * 0.65, 48
		)

func _spawn_rays() -> void:
	for i in 10:
		var angle := (float(i) / 10.0) * TAU + randf_range(-0.15, 0.15)
		var length := randf_range(120.0, 220.0)
		var ray := Line2D.new()
		ray.width = randf_range(2.0, 5.0)
		ray.default_color = Color(1.0, 0.9, 0.5, 1.0)
		ray.material = _add_mat
		ray.z_index = 12
		ray.points = PackedVector2Array([Vector2.ZERO, Vector2.ZERO])
		light_rays.add_child(ray)
		_animate_ray(ray, angle, length)

func _animate_ray(ray: Line2D, angle: float, max_len: float) -> void:
	var dir := Vector2(cos(angle), sin(angle))
	var tween := create_tween()
	tween.tween_method(func(l: float) -> void: ray.points = PackedVector2Array([Vector2.ZERO, dir * l]),
		0.1, max_len, 0.3)
	tween.parallel().tween_property(ray, "modulate:a", 0.0, 1.0)

func _animate_glow() -> void:
	glow_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(glow_rect, "modulate:a", 0.8, 0.1)
	tween.tween_property(glow_rect, "modulate:a", 0.0, 0.4)

func _spiral_pts(r_start: float, r_end: float, ang_start: float, ang_end: float, segs: int) -> PackedVector2Array:
	# Arc from ang_start→ang_end while radius grows r_start→r_end, forming a spiral arm.
	var pts := PackedVector2Array()
	pts.resize(segs + 1)
	for i in range(segs + 1):
		var t := float(i) / segs
		var a := lerpf(ang_start, ang_end, t)
		var r := lerpf(r_start, r_end, t)
		pts[i] = Vector2(cos(a), sin(a)) * r
	return pts
