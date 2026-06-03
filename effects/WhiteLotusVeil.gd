extends Node2D

const SFX := preload("res://assets/sounds/apply_buff_01.wav")

# Instant white sparkle burst + heals all team members for 15 HP.
func fire(data: Dictionary) -> void:
	var arena: Node = data.get("arena")
	var team: int = int(data.get("team", 1))
	position = Vector2.ZERO
	_play_sound()
	_spawn_petal_burst()
	if is_instance_valid(arena):
		arena.heal_team(team, 15)
	var wt := create_tween()
	wt.tween_interval(0.85)
	wt.tween_callback(queue_free)

func _spawn_petal_burst() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# 16 white petal streaks radiating outward
	for i in 16:
		var angle := TAU * float(i) / 16.0 + randf_range(-0.10, 0.10)
		var line := Line2D.new()
		add_child(line)
		line.z_index = 6
		line.material = mat
		line.width = randf_range(1.8, 4.0)
		line.default_color = Color(1.0, 1.0, 0.92, 0.92)
		line.antialiased = true
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.from_angle(angle) * randf_range(14.0, 30.0))
		var t := line.create_tween().set_parallel(true)
		t.tween_property(line, "scale", Vector2(2.2, 2.2), 0.50) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(line, "modulate:a", 0.0, 0.50)
		t.set_parallel(false)
		t.tween_callback(line.queue_free)
	# Outer ring flash
	var ring := Line2D.new()
	add_child(ring)
	ring.z_index = 5
	ring.material = mat
	ring.width = 14.0
	ring.default_color = Color(0.85, 1.0, 0.90, 0.18)
	ring.antialiased = true
	for j in 13:
		ring.add_point(Vector2.from_angle(TAU * float(j) / 12.0) * 18.0)
	var rt := ring.create_tween().set_parallel(true)
	rt.tween_property(ring, "scale", Vector2(3.0, 3.0), 0.50) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	rt.tween_property(ring, "modulate:a", 0.0, 0.50)
	rt.set_parallel(false)
	rt.tween_callback(ring.queue_free)
	# Soft green healing particles rising
	var grad := Gradient.new()
	grad.set_color(0, Color(0.70, 1.0, 0.80, 0.88))
	grad.set_color(1, Color(0.50, 1.0, 0.65, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 18.0
	pm.initial_velocity_max = 55.0
	pm.gravity = Vector3(0.0, -12.0, 0.0)
	pm.scale_min = 0.4
	pm.scale_max = 1.1
	pm.color_ramp = cramp
	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.z_index = 6
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 20
	particles.lifetime = 0.55
	particles.one_shot = true
	particles.explosiveness = 0.72
	particles.emitting = true
	var pmat := CanvasItemMaterial.new()
	pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = pmat
	var pp := create_tween()
	pp.tween_interval(0.85)
	pp.tween_callback(particles.queue_free)

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
