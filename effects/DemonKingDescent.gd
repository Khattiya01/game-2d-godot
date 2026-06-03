extends Node2D
# Private Ultimate — Team B: Demon King's Descent
# 300 DMG + stun 1.5 s to enemies in 300 px + lifesteal 20% of total dmg dealt

const DAMAGE      := 300
const AOE_RADIUS  := 300.0
const STUN_SECS   := 1.5
const LIFESTEAL   := 0.20

func fire(data: Dictionary) -> void:
	var avatar: Node = data.get("avatar")
	var arena:  Node = data.get("arena")
	if not is_instance_valid(avatar):
		queue_free(); return

	global_position = avatar.global_position
	_spawn_descent_columns()
	_spawn_demon_crown()
	_spawn_aura_rings()
	_spawn_particles()
	_spawn_light(global_position, Color(0.75, 0.0, 1.0), 6.5, 7.0)
	if arena and arena.has_method("screen_shake"):
		arena.screen_shake(0.40, 12.0)

	# Damage + stun at impact moment
	get_tree().create_timer(0.32).timeout.connect(func():
		_apply_aoe(avatar, arena)
		_spawn_strike_flash()
	)
	var cleanup := create_tween()
	cleanup.tween_interval(0.88)
	cleanup.tween_callback(queue_free)

# ── Visual builders ────────────────────────────────────────────────────────────

func _spawn_descent_columns() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# 4 dark energy columns descending from above onto avatar
	for i in 4:
		var offset_x := (float(i) - 1.5) * 22.0
		for ld: Array in [[18.0, Color(0.3, 0.0, 0.45, 0.14)], [6.0, Color(0.65, 0.0, 0.88, 0.45)], [1.8, Color(0.88, 0.2, 1.0, 0.90)]]:
			var l := Line2D.new(); l.width = float(ld[0]); l.default_color = ld[1]
			l.material = mat; l.z_index = 5; add_child(l)
			l.add_point(Vector2(offset_x, -160.0)); l.add_point(Vector2(offset_x, 0.0))
			l.scale = Vector2(1.0, 0.0)
			var delay := float(i) * 0.04
			var t := l.create_tween().set_parallel(true)
			t.tween_property(l, "scale", Vector2.ONE, 0.20) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN).set_delay(delay)
			t.tween_property(l, "modulate:a", 0.0, 0.22).set_delay(0.20 + delay)
			t.set_parallel(false); t.tween_callback(l.queue_free)

func _spawn_demon_crown() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Crown: 5 spikes above avatar, center spike tallest
	var spike_heights := [30.0, 50.0, 70.0, 50.0, 30.0]
	for i in 5:
		var x := (float(i) - 2.0) * 14.0
		var h: float = spike_heights[i]
		for ld: Array in [[10.0, Color(0.3, 0.0, 0.45, 0.13)], [3.5, Color(0.7, 0.0, 0.92, 0.50)], [1.0, Color(0.9, 0.3, 1.0, 0.90)]]:
			var l := Line2D.new(); l.width = float(ld[0]); l.default_color = ld[1]
			l.material = mat; l.z_index = 6; add_child(l)
			l.add_point(Vector2(x, -15.0)); l.add_point(Vector2(x, -h - 15.0))
			l.scale = Vector2(1.0, 0.0)
			var t := l.create_tween().set_parallel(true)
			t.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(l, "modulate:a", 0.0, 0.30).set_delay(0.28)
			t.set_parallel(false); t.tween_callback(l.queue_free)

func _spawn_aura_rings() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for ld: Array in [
		[28.0, Color(0.22, 0.0, 0.4,  0.11), AOE_RADIUS * 1.10],
		[12.0, Color(0.55, 0.0, 0.82, 0.38), AOE_RADIUS * 1.00],
		[ 5.0, Color(0.78, 0.05, 0.95, 0.62), AOE_RADIUS * 0.88],
		[ 1.8, Color(1.00, 0.20, 0.45, 0.88), AOE_RADIUS * 0.75],
	]:
		var ring := Line2D.new(); ring.width = float(ld[0]); ring.default_color = ld[1]
		ring.closed = true; ring.antialiased = true; ring.material = mat; ring.z_index = 4
		for i in 24: ring.add_point(Vector2.from_angle(float(i) / 24.0 * TAU) * 12.0)
		add_child(ring)
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2.ONE * (float(ld[2]) / 12.0), 0.48) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.48)
		t.set_parallel(false); t.tween_callback(ring.queue_free)

func _spawn_particles() -> void:
	var grad := Gradient.new(); grad.set_color(0, Color(0.72, 0.0, 1.0, 0.95)); grad.set_color(1, Color(0.35, 0.0, 0.5, 0.0))
	var cramp := GradientTexture1D.new(); cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 18.0
	pm.direction = Vector3(0.0, -1.0, 0.0); pm.spread = 180.0
	pm.initial_velocity_min = 160.0; pm.initial_velocity_max = 440.0
	pm.gravity = Vector3.ZERO; pm.scale_min = 1.0; pm.scale_max = 3.2; pm.color_ramp = cramp
	var p := GPUParticles2D.new(); add_child(p); p.z_index = 6
	p.texture = _make_circ_tex(); p.process_material = pm
	p.amount = 58; p.lifetime = 0.65; p.one_shot = true; p.explosiveness = 0.90; p.emitting = true
	var pmat := CanvasItemMaterial.new(); pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; p.material = pmat
	var t := create_tween(); t.tween_interval(0.90); t.tween_callback(p.queue_free)

func _spawn_strike_flash() -> void:
	var cl := CanvasLayer.new(); cl.layer = 16; add_child(cl)
	var rect := ColorRect.new(); rect.color = Color(0.18, 0.0, 0.30, 0.0); rect.size = Vector2(1920, 1080); cl.add_child(rect)
	var t := rect.create_tween()
	t.tween_property(rect, "color:a", 0.48, 0.07)
	t.tween_property(rect, "color:a", 0.0,  0.35)
	t.tween_callback(cl.queue_free)

func _apply_aoe(avatar: Node, arena: Node) -> void:
	if not arena or not arena.has_method("get_all_alive_avatars"): return
	var my_team := int(avatar.get("_team") if is_instance_valid(avatar) else 1)
	var center: Vector2 = avatar.global_position if is_instance_valid(avatar) else global_position
	var kid     := str(avatar.get("player_id")) if is_instance_valid(avatar) else ""
	var total_dmg_dealt := 0
	for av in arena.get_all_alive_avatars():
		if av.get("_team") != my_team and av.global_position.distance_to(center) <= AOE_RADIUS:
			if av.has_method("take_damage"):
				av.take_damage(DAMAGE, kid)
				total_dmg_dealt += DAMAGE
			if av.has_method("stun"): av.stun(STUN_SECS)
	# Lifesteal: heal avatar 20% of total damage dealt
	if total_dmg_dealt > 0 and is_instance_valid(avatar) and avatar.has_method("heal"):
		avatar.heal(maxi(1, int(float(total_dmg_dealt) * LIFESTEAL)))

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
