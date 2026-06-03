extends Node2D

const DASH_DIST: float      = 200.0
const DASH_DURATION: float  = 0.15
const INVINCIBLE_SEC: float = 0.20
const SFX := preload("res://assets/sounds/cloud_step_01.wav")

func fire(data: Dictionary) -> void:
	var avatar: Node = data.get("avatar")
	if not is_instance_valid(avatar):
		queue_free()
		return

	var vel_var = avatar.get("_velocity")
	var vel: Vector2 = vel_var if vel_var is Vector2 else Vector2.ZERO
	var direction: Vector2 = vel.normalized() if vel.length_squared() > 0.01 else \
		(Vector2.RIGHT if avatar.get("_team") == 1 else Vector2.LEFT)

	var start: Vector2 = avatar.global_position
	var end: Vector2   = _clamp_zone(start + direction * DASH_DIST, avatar.get("_zone_rect"))

	avatar.set("_is_dashing", true)
	_play_sound(start)

	# 1. 3-layer streak trail along full path
	_spawn_streaks(start, end)
	# 2. GPUParticles2D — particles kicked up in the avatar's wake
	_spawn_particle_trail(start, direction)

	# Brief white flash on avatar during slide
	var flash := create_tween()
	flash.tween_property(avatar, "modulate", Color(1.9, 1.9, 1.9, 1.0), 0.04)
	flash.tween_property(avatar, "modulate", Color.WHITE, DASH_DURATION)

	# Smooth dash movement (physics skipped while _is_dashing)
	var move := create_tween()
	move.tween_property(avatar, "global_position", end, DASH_DURATION) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	move.tween_callback(func():
		avatar.set("_velocity", direction * float(avatar.get("_base_speed") if avatar.get("_base_speed") else 100.0))
		# 3. 3-layer ring + PointLight2D cyan flash at destination
		_spawn_arrival(end)
	)

	var finish := create_tween()
	finish.tween_interval(INVINCIBLE_SEC)
	finish.tween_callback(func():
		if is_instance_valid(avatar):
			avatar.set("_is_dashing", false)
	)

	var cleanup := create_tween()
	cleanup.tween_interval(0.60)
	cleanup.tween_callback(queue_free)

# ── Helpers ───────────────────────────────────────────────────────────────────

func _play_sound(pos: Vector2) -> void:
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.global_position = pos
	player.stream = SFX
	player.play()
	player.finished.connect(player.queue_free)

func _clamp_zone(pos: Vector2, zone) -> Vector2:
	if not zone is Rect2 or (zone as Rect2).size == Vector2.ZERO:
		return pos
	var z := zone as Rect2
	return Vector2(clampf(pos.x, z.position.x + 20.0, z.end.x - 20.0),
				   clampf(pos.y, z.position.y + 20.0, z.end.y - 20.0))

func _spawn_streaks(start: Vector2, end: Vector2) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# 3-layer definition: [width_px, color]
	var layer_defs: Array = [
		[16.0, Color(0.50, 1.0, 1.0, 0.13)],  # aura
		[6.5,  Color(0.80, 1.0, 1.0, 0.55)],  # glow
		[1.8,  Color(0.95, 1.0, 1.0, 1.00)],  # core
	]
	for i in 5:
		var t0 := float(i) / 5.0
		var t1 := minf(t0 + 0.24, 1.0)
		var p0 := start.lerp(end, t0)
		var p1 := start.lerp(end, t1)
		var delay := float(i) * 0.018
		for ld in layer_defs:
			var line := Line2D.new()
			add_child(line)
			line.z_index = 5
			line.material = mat
			line.width = float(ld[0])
			line.default_color = ld[1]
			line.antialiased = true
			line.add_point(p0)
			line.add_point(p1)
			var fade := line.create_tween()
			if delay > 0.0:
				fade.tween_interval(delay)
			fade.tween_property(line, "modulate:a", 0.0, DASH_DURATION + 0.10)
			fade.tween_callback(line.queue_free)

func _spawn_particle_trail(start: Vector2, direction: Vector2) -> void:
	# Color ramp: white-cyan → transparent
	var grad := Gradient.new()
	grad.set_color(0, Color(0.60, 1.0, 1.0, 0.90))
	grad.set_color(1, Color(0.75, 1.0, 1.0, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	# Emit backward (opposite dash) = particles blown in avatar's wake
	pm.direction = Vector3(-direction.x, -direction.y, 0.0)
	pm.spread = 32.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 210.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.7
	pm.color_ramp = cramp

	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.global_position = start
	particles.z_index = 6
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 22
	particles.lifetime = 0.30
	particles.one_shot = true
	particles.explosiveness = 0.25
	particles.emitting = true
	var pmat := CanvasItemMaterial.new()
	pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = pmat

	var timer := create_tween()
	timer.tween_interval(0.65)
	timer.tween_callback(particles.queue_free)

func _spawn_arrival(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# 3-layer expanding ring: aura → glow → core
	var ring_defs: Array = [
		[18.0, Color(0.40, 1.0, 1.0, 0.13)],
		[7.0,  Color(0.75, 1.0, 1.0, 0.55)],
		[2.0,  Color(0.95, 1.0, 1.0, 0.95)],
	]
	for ld in ring_defs:
		var ring := Line2D.new()
		add_child(ring)
		ring.global_position = pos   # origin at pos → points are relative
		ring.z_index = 6
		ring.material = mat
		ring.width = float(ld[0])
		ring.default_color = ld[1]
		ring.antialiased = true
		for j in 13:
			ring.add_point(Vector2.from_angle(TAU * float(j) / 12.0) * 16.0)
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.28) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.28)
		t.set_parallel(false)
		t.tween_callback(ring.queue_free)

	# PointLight2D — cyan flash at landing point
	_spawn_point_light(pos, Color(0.25, 0.90, 1.0), 3.2, 2.8)

func _spawn_point_light(pos: Vector2, col: Color, energy: float, tex_scale: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 1))
	grad.add_point(0.3, Color(col.r, col.g, col.b, 0.5))
	grad.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = grad
	tex.width  = 128
	tex.height = 128

	var light := PointLight2D.new()
	add_child(light)
	light.global_position = pos
	light.texture       = tex
	light.texture_scale = tex_scale
	light.energy        = energy
	light.color         = col

	var t := create_tween()
	t.tween_property(light, "energy", 0.0, 0.32)
	t.tween_callback(light.queue_free)

func _make_circle_tex() -> ImageTexture:
	const S := 8
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c   := Vector2(S * 0.5, S * 0.5)
	for y in S:
		for x in S:
			var a := clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(c) / (S * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
