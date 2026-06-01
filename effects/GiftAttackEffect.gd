extends Node2D

@onready var projectile: Node2D = $Projectile
@onready var projectile_sprite: Sprite2D = $Projectile/ProjectileSprite
@onready var trail_particles: GPUParticles2D = $Projectile/TrailParticles
@onready var explosion_particles: GPUParticles2D = $ExplosionParticles

var _flying: bool = false

func fire(from_team: int, arena: Node) -> void:
	var vp := get_viewport_rect().size
	var start := Vector2(
		vp.x * (0.13 if from_team == 1 else 0.87),
		vp.y * 0.5 + randf_range(-80.0, 80.0)
	)
	var end_pos := Vector2(
		vp.x * (0.87 if from_team == 1 else 0.13),
		vp.y * 0.5 + randf_range(-80.0, 80.0)
	)
	var dir := 1.0 if from_team == 1 else -1.0

	projectile.position = start
	_flying = true

	# Duplicate so direction change doesn't affect other simultaneous effects
	var trail_mat: ParticleProcessMaterial = trail_particles.process_material.duplicate()
	trail_particles.process_material = trail_mat
	trail_mat.direction = Vector3(-dir, randf_range(-0.15, 0.15), 0.0)
	trail_particles.emitting = true

	var tween := create_tween()
	tween.tween_method(_move_arc.bind(start, end_pos), 0.0, 1.0, 0.9)
	tween.tween_callback(_on_impact.bind(arena, 3 - from_team))

func _move_arc(t: float, start: Vector2, end_pos: Vector2) -> void:
	projectile.position = start.lerp(end_pos, t) + Vector2(0.0, -100.0 * sin(t * PI))

func _on_impact(arena: Node, target_team: int) -> void:
	_flying = false
	trail_particles.emitting = false
	projectile.visible = false

	explosion_particles.position = projectile.position
	explosion_particles.emitting = true

	if arena.has_method("screen_shake"):
		arena.screen_shake(0.3, 8.0)
	if arena.has_method("knockback_team"):
		arena.knockback_team(target_team)
	if arena.has_method("get_nearest_on_team"):
		var victim: Node = arena.get_nearest_on_team(explosion_particles.position, target_team)
		if victim and is_instance_valid(victim) and victim.has_method("take_damage"):
			victim.take_damage(10)

	await get_tree().create_timer(explosion_particles.lifetime + 0.3).timeout
	queue_free()

func _process(delta: float) -> void:
	if _flying:
		projectile_sprite.rotation += delta * 4.0
