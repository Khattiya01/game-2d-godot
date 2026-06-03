extends Node2D

const DASH_DIST: float = 200.0
const SFX := preload("res://assets/sounds/shadow_blink_01.wav")

func fire(data: Dictionary) -> void:
	var avatar: Node = data.get("avatar")
	if not is_instance_valid(avatar):
		queue_free()
		return

	var vel_var = avatar.get("_velocity")
	var vel: Vector2 = vel_var if vel_var is Vector2 else Vector2.ZERO
	var direction: Vector2 = vel.normalized() if vel.length_squared() > 0.01 else \
		(Vector2.LEFT if avatar.get("_team") == 2 else Vector2.RIGHT)

	var start: Vector2 = avatar.global_position
	var end: Vector2   = _clamp_zone(start + direction * DASH_DIST, avatar.get("_zone_rect"))

	avatar.set("_is_dashing", true)

	# 1. Origin: Polygon2D smoke puffs + GPUParticles2D dark burst
	_spawn_origin_smoke(start)
	_spawn_origin_particles(start)

	# Phase 1 (0–0.08s): flash purple → avatar fades to invisible
	# Phase 2 (0.08s)  : instant teleport → spawn 3-layer sparks + PointLight2D
	# Phase 3 (0.08–0.20s): fade back in → end invincibility
	var seq := create_tween()
	seq.tween_property(avatar, "modulate", Color(0.55, 0.0, 0.55, 1.0), 0.04)
	seq.tween_property(avatar, "modulate", Color(0.30, 0.0, 0.35, 0.0), 0.04)
	seq.tween_callback(func():
		_play_sound(end)
		avatar.global_position = end
		avatar.set("_velocity", direction * float(avatar.get("_base_speed") if avatar.get("_base_speed") else 100.0))
		# 2. Destination: 3-layer sparks + ring + GPUParticles2D + PointLight2D
		_spawn_arrival(end)
	)
	seq.tween_property(avatar, "modulate", Color.WHITE, 0.12)
	seq.tween_callback(func():
		if is_instance_valid(avatar):
			avatar.set("_is_dashing", false)
	)

	var cleanup := create_tween()
	cleanup.tween_interval(0.65)
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

func _spawn_origin_smoke(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 5:
		var puff := Polygon2D.new()
		add_child(puff)
		puff.z_index = 5
		puff.global_position = pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0))
		puff.material = mat
		var r := randf_range(8.0, 14.0)
		var pts := PackedVector2Array()
		for j in 6:
			pts.append(Vector2.from_angle(TAU * float(j) / 6.0 + randf_range(-0.25, 0.25)) * r)
		puff.polygon = pts
		puff.color = Color(0.38, 0.0, 0.48, 0.55)
		var delay := float(i) * 0.028
		var t := puff.create_tween().set_parallel(true)
		t.tween_property(puff, "scale", Vector2(2.8, 2.8), 0.32).set_delay(delay) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(puff, "modulate:a", 0.0, 0.32).set_delay(delay)
		t.set_parallel(false)
		t.tween_callback(puff.queue_free)

func _spawn_origin_particles(pos: Vector2) -> void:
	# Dark purple particles rising upward = "shadow matter evaporating"
	var grad := Gradient.new()
	grad.set_color(0, Color(0.55, 0.0, 0.75, 0.90))
	grad.set_color(1, Color(0.30, 0.0, 0.45, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, -1.0, 0.0)  # upward
	pm.spread = 70.0
	pm.initial_velocity_min = 30.0
	pm.initial_velocity_max = 130.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.6
	pm.scale_max = 1.8
	pm.color_ramp = cramp

	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.global_position = pos
	particles.z_index = 6
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 18
	particles.lifetime = 0.35
	particles.one_shot = true
	particles.explosiveness = 0.75
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

	# 3-layer spark lines radiating outward
	# Each spark: aura(12px/0.13) → glow(4.5px/0.55) → core(1.5px/1.0)
	var spark_defs: Array = [
		[12.0, Color(0.50, 0.00, 0.80, 0.13)],
		[4.5,  Color(0.75, 0.00, 1.00, 0.55)],
		[1.5,  Color(0.90, 0.40, 1.00, 1.00)],
	]
	for i in 8:
		var angle := TAU * float(i) / 8.0 + randf_range(-0.2, 0.2)
		var dist  := randf_range(18.0, 32.0)
		for sd in spark_defs:
			var line := Line2D.new()
			add_child(line)
			# Set origin to pos so scale tween expands from spark center
			line.global_position = pos
			line.z_index = 6
			line.material = mat
			line.width = float(sd[0])
			line.default_color = sd[1]
			line.antialiased = true
			line.add_point(Vector2.ZERO)
			line.add_point(Vector2.from_angle(angle) * dist)
			var t := line.create_tween().set_parallel(true)
			t.tween_property(line, "modulate:a", 0.0, 0.24)
			t.tween_property(line, "scale", Vector2(1.7, 1.7), 0.24) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.set_parallel(false)
			t.tween_callback(line.queue_free)

	# 3-layer expanding ring
	var ring_defs: Array = [
		[18.0, Color(0.40, 0.00, 0.65, 0.12)],
		[6.5,  Color(0.65, 0.00, 0.90, 0.55)],
		[2.0,  Color(0.85, 0.30, 1.00, 0.95)],
	]
	for rd in ring_defs:
		var ring := Line2D.new()
		add_child(ring)
		ring.global_position = pos   # origin at pos → points are relative
		ring.z_index = 5
		ring.material = mat
		ring.width = float(rd[0])
		ring.default_color = rd[1]
		ring.antialiased = true
		for j in 13:
			ring.add_point(Vector2.from_angle(TAU * float(j) / 12.0) * 14.0)
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2(3.5, 3.5), 0.32) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.32)
		t.set_parallel(false)
		t.tween_callback(ring.queue_free)

	# GPUParticles2D — omnidirectional purple burst at destination
	_spawn_arrival_particles(pos)

	# PointLight2D — purple flash at landing point
	_spawn_point_light(pos, Color(0.65, 0.0, 0.90), 3.5, 3.0)

func _spawn_arrival_particles(pos: Vector2) -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 0.0, 1.00, 0.95))
	grad.set_color(1, Color(0.40, 0.0, 0.60, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 180.0  # omnidirectional burst
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = 240.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 0.5
	pm.scale_max = 1.6
	pm.color_ramp = cramp

	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.global_position = pos
	particles.z_index = 6
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 22
	particles.lifetime = 0.30
	particles.one_shot = true
	particles.explosiveness = 0.88
	particles.emitting = true
	var pmat := CanvasItemMaterial.new()
	pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = pmat

	var timer := create_tween()
	timer.tween_interval(0.65)
	timer.tween_callback(particles.queue_free)

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
