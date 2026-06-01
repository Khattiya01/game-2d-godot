extends Node2D

@onready var burst_particles: GPUParticles2D = $BurstParticles

func fire(effect_data: Dictionary) -> void:
	position = effect_data.get("position", Vector2.ZERO)
	burst_particles.emitting = true
	await get_tree().create_timer(burst_particles.lifetime + 0.15).timeout
	queue_free()
