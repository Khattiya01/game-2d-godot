extends Node2D

const FLY_TIME: float = 1.00
const ARC_HEIGHT: float = -120.0
const BASE_DAMAGE: int = 20
const DMG_FACTOR: float = 1.2    # single-target bonus; total ≈ 1.2× base + 1.5 s stun utility
const STUN_DURATION: float = 1.5

@onready var projectile: Node2D = $Projectile
@onready var rock_shape: Polygon2D = $Projectile/RockShape
@onready var trail_particles: GPUParticles2D = $Projectile/TrailParticles
@onready var impact_particles: GPUParticles2D = $ImpactParticles
@onready var launch_sound: AudioStreamPlayer2D = $LaunchSound
@onready var hit_sound: AudioStreamPlayer2D = $HitSound

var _flying: bool = false
var _arena: Node = null
var _target_node: Node = null
var _on_complete: Callable
var _base_dmg: int = BASE_DAMAGE
var _dmg_mult: float = 1.0

func _ready() -> void:
	rock_shape.polygon = PackedVector2Array([
		Vector2(0, -13), Vector2(10, -8), Vector2(14, 1),
		Vector2(9, 10), Vector2(2, 14), Vector2(-9, 11),
		Vector2(-13, 2), Vector2(-10, -9),
	])

func fire(effect_data: Dictionary) -> void:
	var from_pos: Vector2 = effect_data.get("from_pos", Vector2.ZERO)
	_target_node = effect_data.get("target", null)
	_arena = effect_data.get("arena", null)
	_on_complete = effect_data.get("on_complete", Callable())
	_base_dmg = int(effect_data.get("base_dmg", BASE_DAMAGE))
	_dmg_mult = effect_data.get("damage_mult", 1.0)

	var end_pos: Vector2 = _target_node.global_position \
		if _target_node and is_instance_valid(_target_node) \
		else from_pos + Vector2(500.0, 0.0)

	projectile.position = from_pos
	_flying = true
	launch_sound.position = from_pos
	launch_sound.play()

	var dir := (end_pos - from_pos).normalized()
	var trail_mat: ParticleProcessMaterial = trail_particles.process_material.duplicate()
	trail_particles.process_material = trail_mat
	trail_mat.direction = Vector3(-dir.x, -dir.y, 0.0)
	trail_particles.emitting = true

	var tween := create_tween()
	tween.tween_method(_move_arc.bind(from_pos, end_pos), 0.0, 1.0, FLY_TIME)
	tween.tween_callback(_on_impact)

func _move_arc(t: float, start: Vector2, end_pos: Vector2) -> void:
	projectile.position = start.lerp(end_pos, t) + Vector2(0.0, ARC_HEIGHT * sin(t * PI))

func _on_impact() -> void:
	_flying = false
	trail_particles.emitting = false
	rock_shape.visible = false

	impact_particles.position = projectile.position
	impact_particles.emitting = true
	if launch_sound.playing:
		launch_sound.stop()
	hit_sound.position = projectile.position
	hit_sound.play()

	if _arena and is_instance_valid(_arena) and _arena.has_method("screen_shake"):
		_arena.screen_shake(0.35, 9.0)

	if _target_node and is_instance_valid(_target_node):
		var dmg := maxi(1, int(float(_base_dmg) * DMG_FACTOR * _dmg_mult))
		if _target_node.has_method("take_damage"):
			_target_node.take_damage(dmg)
		if _target_node.has_method("stun"):
			_target_node.stun(STUN_DURATION)
		_spawn_stun_indicator(_target_node)

	if _on_complete.is_valid():
		_on_complete.call()

	await get_tree().create_timer(impact_particles.lifetime + 0.3).timeout
	queue_free()

func _spawn_stun_indicator(target: Node) -> void:
	var indicator := Node2D.new()
	indicator.position = Vector2(0.0, -42.0)
	target.add_child(indicator)

	var star_colors := [
		Color(1.0, 0.90, 0.10, 1.0),
		Color(1.0, 0.75, 0.00, 1.0),
		Color(1.0, 0.96, 0.55, 1.0),
	]
	for i in 5:
		var star := Polygon2D.new()
		star.color = star_colors[i % star_colors.size()]
		star.polygon = _make_star_pts(6.0)
		var base_angle := (float(i) / 5.0) * TAU
		star.position = Vector2(cos(base_angle), sin(base_angle)) * 20.0
		indicator.add_child(star)

	var rot_tween := indicator.create_tween().set_loops()
	rot_tween.tween_property(indicator, "rotation", TAU, 1.5) \
		.set_trans(Tween.TRANS_LINEAR)

	# Use signal lambda instead of await — coroutines on StunProjectile are dropped
	# when it queue_free()s (at ~1.15 s), which is before STUN_DURATION (1.5 s) ends.
	get_tree().create_timer(STUN_DURATION - 0.25).timeout.connect(func():
		if not is_instance_valid(indicator):
			return
		rot_tween.kill()
		var fade := indicator.create_tween()
		fade.tween_property(indicator, "modulate:a", 0.0, 0.25)
		fade.tween_callback(indicator.queue_free)
	)

func _make_star_pts(radius: float) -> PackedVector2Array:
	var pts: PackedVector2Array = []
	var inner := radius * 0.4
	for i in 10:
		var angle := (float(i) / 10.0) * TAU - PI * 0.5
		var r := radius if i % 2 == 0 else inner
		pts.append(Vector2(cos(angle), sin(angle)) * r)
	return pts

func _process(delta: float) -> void:
	if _flying:
		rock_shape.rotation += delta * 5.5
