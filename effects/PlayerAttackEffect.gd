extends Node2D

const DAMAGE := 5

var _target: Node = null
var _on_complete: Callable = Callable()
var _damage_mult: float = 1.0

func fire(effect_data: Dictionary) -> void:
	var from_pos: Vector2 = effect_data.get("from_pos", Vector2.ZERO)
	var target_pos: Vector2 = effect_data.get("target_pos", Vector2.ZERO)
	_target = effect_data.get("target", null)
	_on_complete = effect_data.get("on_complete", Callable())
	_damage_mult = effect_data.get("damage_mult", 1.0)

	$ShotSound.position = from_pos
	$ShotSound.play()
	$Projectile.position = from_pos

	var dir := (target_pos - from_pos).normalized()
	var trail_mat: ParticleProcessMaterial = $Projectile/TrailParticles.process_material.duplicate()
	$Projectile/TrailParticles.process_material = trail_mat
	trail_mat.direction = Vector3(-dir.x, -dir.y, 0.0)
	$Projectile/TrailParticles.emitting = true

	var tween := create_tween()
	tween.tween_property($Projectile, "position", target_pos, 0.3)
	tween.tween_callback(_on_impact)

func _on_impact() -> void:
	$Projectile/TrailParticles.emitting = false
	$Projectile.visible = false
	if _target and is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(int(float(DAMAGE) * _damage_mult))
	if _on_complete.is_valid():
		_on_complete.call()
	await get_tree().create_timer(0.1).timeout
	queue_free()
