extends Node2D
# Private Ultimate — Team A: Dragon Soul Ascension
# 300 DMG AoE 300 px + self-heal 50% max HP, ~0.8 s animation

const DAMAGE    := 300
const AOE_RADIUS := 300.0
const HEAL_RATIO := 0.5   # 50% of max HP

func fire(data: Dictionary) -> void:
	var avatar: Node = data.get("avatar")
	var arena:  Node = data.get("arena")
	if not is_instance_valid(avatar):
		queue_free(); return

	global_position = avatar.global_position
	_spawn_ground_ring()
	_spawn_dragon_body()
	_spawn_wing_arcs()
	_spawn_particles()
	_spawn_light(global_position, Color(0.35, 1.0, 0.85), 6.0, 6.5)
	if arena and arena.has_method("screen_shake"):
		arena.screen_shake(0.35, 10.0)

	# Damage at peak (0.35 s into animation)
	get_tree().create_timer(0.35).timeout.connect(func():
		_apply_aoe(avatar, arena)
		_spawn_strike_flash()
	)
	# Self-heal
	get_tree().create_timer(0.42).timeout.connect(func():
		if is_instance_valid(avatar) and avatar.has_method("heal"):
			var stats = avatar.get("_avatar_stats")
			var max_hp: int = stats.get_max_hp() if is_instance_valid(stats) else 200
			avatar.heal(int(float(max_hp) * HEAL_RATIO))
	)
	var cleanup := create_tween()
	cleanup.tween_interval(0.85)
	cleanup.tween_callback(queue_free)

# ── Visual builders ────────────────────────────────────────────────────────────

func _spawn_ground_ring() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for ld: Array in [[24.0, Color(0.4, 1.0, 0.9, 0.12)], [10.0, Color(0.2, 0.92, 1.0, 0.35)], [2.5, Color(0.9, 1.0, 1.0, 0.90)]]:
		var ring := Line2D.new(); ring.width = float(ld[0]); ring.default_color = ld[1]
		ring.closed = true; ring.antialiased = true; ring.material = mat; ring.z_index = 4
		for i in 24: ring.add_point(Vector2.from_angle(float(i) / 24.0 * TAU) * 12.0)
		add_child(ring)
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2.ONE * (AOE_RADIUS * 0.9 / 12.0), 0.45) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.45)
		t.set_parallel(false); t.tween_callback(ring.queue_free)

func _spawn_dragon_body() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Serpentine body curving upward: S-curve from avatar upward ~130 px
	var body_pts: Array[Vector2] = [
		Vector2(0, 0), Vector2(18, -28), Vector2(-12, -55),
		Vector2(20, -85), Vector2(-8, -115), Vector2(5, -140),
	]
	for ld: Array in [[16.0, Color(0.3, 0.9, 1.0, 0.15)], [6.0, Color(0.5, 1.0, 1.0, 0.50)], [1.8, Color(1.0, 1.0, 1.0, 0.95)]]:
		var l := Line2D.new(); l.width = float(ld[0]); l.default_color = ld[1]
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND; l.end_cap_mode = Line2D.LINE_CAP_ROUND
		l.material = mat; l.z_index = 6; add_child(l)
		for p in body_pts: l.add_point(p)
		l.scale = Vector2(0.0, 0.0)
		var t := l.create_tween().set_parallel(true)
		t.tween_property(l, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "modulate:a", 0.0, 0.45).set_delay(0.35)
		t.set_parallel(false); t.tween_callback(l.queue_free)
	# Claw tips at the head
	_spawn_claw_lines(Vector2(5, -140), mat)

func _spawn_claw_lines(origin: Vector2, mat: CanvasItemMaterial) -> void:
	for i in 4:
		var ang := deg_to_rad(-50.0 + float(i) * 35.0)
		var l := Line2D.new(); l.width = 2.5; l.default_color = Color(0.8, 1.0, 0.55, 0.85)
		l.material = mat; l.z_index = 7; add_child(l)
		l.add_point(origin); l.add_point(origin + Vector2.from_angle(ang - PI * 0.5) * 24.0)
		var t := l.create_tween().set_parallel(true)
		t.tween_property(l, "modulate:a", 0.0, 0.30).set_delay(0.25)
		t.tween_property(l, "scale", Vector2(1.8, 1.8), 0.25) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.set_parallel(false); t.tween_callback(l.queue_free)

func _spawn_wing_arcs() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for side in [-1.0, 1.0]:
		var pts: Array[Vector2] = []
		for j in 10:
			var a := float(j) / 9.0
			var ang := deg_to_rad(side * lerpf(20.0, 110.0, a))
			pts.append(Vector2.from_angle(ang - PI * 0.5) * lerpf(18.0, 75.0, a * a))
		for ld: Array in [[14.0, Color(0.35, 0.95, 1.0, 0.12)], [5.0, Color(0.5, 1.0, 1.0, 0.45)], [1.5, Color(0.85, 1.0, 0.75, 0.90)]]:
			var l := Line2D.new(); l.width = float(ld[0]); l.default_color = ld[1]
			l.material = mat; l.z_index = 5; add_child(l)
			for p in pts: l.add_point(p)
			l.scale = Vector2.ZERO
			var t := l.create_tween().set_parallel(true)
			t.tween_property(l, "scale", Vector2.ONE, 0.22) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(l, "modulate:a", 0.0, 0.32).set_delay(0.20)
			t.set_parallel(false); t.tween_callback(l.queue_free)

func _spawn_particles() -> void:
	var grad := Gradient.new(); grad.set_color(0, Color(0.6, 1.0, 0.9, 1.0)); grad.set_color(1, Color(0.3, 0.85, 1.0, 0.0))
	var cramp := GradientTexture1D.new(); cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 20.0
	pm.direction = Vector3(0.0, -1.0, 0.0); pm.spread = 180.0
	pm.initial_velocity_min = 150.0; pm.initial_velocity_max = 420.0
	pm.gravity = Vector3.ZERO; pm.scale_min = 1.2; pm.scale_max = 3.5; pm.color_ramp = cramp
	var p := GPUParticles2D.new(); add_child(p); p.z_index = 6
	p.texture = _make_circ_tex(); p.process_material = pm
	p.amount = 55; p.lifetime = 0.65; p.one_shot = true; p.explosiveness = 0.88; p.emitting = true
	var pmat := CanvasItemMaterial.new(); pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; p.material = pmat
	var t := create_tween(); t.tween_interval(0.90); t.tween_callback(p.queue_free)

func _spawn_strike_flash() -> void:
	var cl := CanvasLayer.new(); cl.layer = 16; add_child(cl)
	var rect := ColorRect.new(); rect.color = Color(0.3, 1.0, 0.85, 0.0); rect.size = Vector2(1920, 1080); cl.add_child(rect)
	var t := rect.create_tween()
	t.tween_property(rect, "color:a", 0.45, 0.06)
	t.tween_property(rect, "color:a", 0.0,  0.30)
	t.tween_callback(cl.queue_free)

func _apply_aoe(avatar: Node, arena: Node) -> void:
	if not arena or not arena.has_method("get_all_alive_avatars"): return
	var my_team := int(avatar.get("_team") if is_instance_valid(avatar) else 1)
	var center: Vector2 = avatar.global_position if is_instance_valid(avatar) else global_position
	var kid     := str(avatar.get("player_id")) if is_instance_valid(avatar) else ""
	for av in arena.get_all_alive_avatars():
		if av.get("_team") != my_team and av.global_position.distance_to(center) <= AOE_RADIUS:
			if av.has_method("take_damage"): av.take_damage(DAMAGE, kid)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.60); t.tween_callback(light.queue_free)

func _make_circ_tex() -> ImageTexture:
	const S := 8; var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c := Vector2(S * 0.5, S * 0.5)
	for y in S:
		for x in S:
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(c) / (S * 0.5), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)
