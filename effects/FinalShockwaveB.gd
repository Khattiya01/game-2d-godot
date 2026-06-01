extends Node2D

# Purple-pink electric shockwave for Team B ultimate impact.

@onready var ring1: Line2D = $ShockwaveRing1
@onready var ring2: Line2D = $ShockwaveRing2
@onready var ring3: Line2D = $ShockwaveRing3
@onready var sparks: GPUParticles2D = $SparkParticles
@onready var flash_rect: ColorRect = $GlowOverlay/FlashRect
@onready var sfx: AudioStreamPlayer = $ExplosionSFX

func play(center: Vector2) -> void:
	global_position = center
	sfx.play()
	sparks.emitting = true
	_animate_ring(ring1, 0.0,  1.30, 300.0)
	_animate_ring(ring2, 0.10, 1.45, 280.0)
	_animate_ring(ring3, 0.20, 1.60, 260.0)
	_flash_glow()
	await get_tree().create_timer(2.2, true).timeout
	queue_free()

func _animate_ring(ring: Line2D, delay: float, duration: float, max_r: float) -> void:
	ring.points = _circle_pts(0.1, 32)
	if delay > 0.0:
		await get_tree().create_timer(delay, true).timeout
	var tween := create_tween()
	tween.tween_method(
		func(r: float) -> void: ring.points = _circle_pts(r, 32),
		0.1, max_r, duration
	)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, duration)

func _flash_glow() -> void:
	flash_rect.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(flash_rect, "modulate:a", 0.3, 0.1)
	tween.tween_property(flash_rect, "modulate:a", 0.0, 0.1)

func _circle_pts(radius: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(segments + 1)
	for i in range(segments + 1):
		var a := (float(i) / segments) * TAU
		pts[i] = Vector2(cos(a), sin(a)) * radius
	return pts
