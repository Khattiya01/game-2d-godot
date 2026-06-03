extends Node2D
# T4d Team A — white nova flash, ×15, stun 2 s, AoE 450 px (no game pause)

const DMG_FACTOR  := 15.0
const AOE_RADIUS  := 450.0
const STUN_SECS   := 2.0
const NOVA_EXPAND := 0.50   # ring expansion time

func fire(data: Dictionary) -> void:
	var attacker: Node = data.get("attacker")
	var target:   Node = data.get("target")
	var arena:    Node = data.get("arena")
	var dmult: float   = data.get("damage_mult", 1.0)
	var base: int      = int(data.get("base_dmg", 10))

	if not is_instance_valid(attacker):
		queue_free(); return

	var center: Vector2 = target.global_position if is_instance_valid(target) else attacker.global_position
	global_position = center
	var kid := str(attacker.get("player_id")) if is_instance_valid(attacker) else ""
	var dmg := maxi(1, int(float(base) * DMG_FACTOR * dmult))

	_spawn_charge(attacker.global_position)  # charge windup stays at attacker

	var tw := create_tween()
	tw.tween_interval(0.18)   # brief charge
	tw.tween_callback(func():
		_spawn_screen_flash()
		_spawn_nova_rings(global_position)
		_spawn_particles(global_position)
		_apply_aoe(attacker, arena, global_position, dmg, kid)
		if arena and arena.has_method("screen_shake"):
			arena.screen_shake(0.50, 15.0)
	)
	tw.tween_interval(NOVA_EXPAND + 0.45)
	tw.tween_callback(queue_free)

func _spawn_charge(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Ascending glow rings converging upward
	for i in 3:
		var ring := Line2D.new(); ring.width = float(5 - i * 1); ring.default_color = Color(0.7, 1.0, 0.75, 0.25 + float(i) * 0.12)
		ring.closed = true; ring.material = mat
		for j in 20: ring.add_point(Vector2.from_angle(float(j) / 20.0 * TAU) * (35.0 + float(i) * 20.0))
		ring.global_position = pos; add_child(ring)
		var t := ring.create_tween()
		t.tween_property(ring, "scale", Vector2(0.1, 0.1), 0.18).set_delay(float(i) * 0.04)
		t.tween_callback(ring.queue_free)

func _spawn_screen_flash() -> void:
	var cl := CanvasLayer.new(); cl.layer = 16; add_child(cl)
	var rect := ColorRect.new(); rect.color = Color(1.0, 1.0, 1.0, 0.0); rect.size = Vector2(1920, 1080); cl.add_child(rect)
	var t := rect.create_tween()
	t.tween_property(rect, "color:a", 0.85, 0.08)
	t.tween_property(rect, "color:a", 0.0,  0.55)
	t.tween_callback(cl.queue_free)

func _spawn_nova_rings(center: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# 5 rings staggered size / timing
	var ring_defs: Array = [
		[30.0, Color(0.65, 0.98, 1.0, 0.12), AOE_RADIUS * 1.20, 0.0],
		[16.0, Color(0.80, 1.00, 0.90, 0.35), AOE_RADIUS * 1.10, 0.02],
		[ 8.0, Color(0.92, 1.00, 0.95, 0.65), AOE_RADIUS * 1.00, 0.04],
		[ 3.0, Color(1.00, 1.00, 1.00, 0.90), AOE_RADIUS * 0.92, 0.06],
		[ 1.2, Color(0.85, 0.95, 0.50, 1.00), AOE_RADIUS * 0.80, 0.08],
	]
	for rd: Array in ring_defs:
		var ring := _make_ring_line(float(rd[0]), rd[1], 16.0)
		ring.global_position = center; ring.material = mat; add_child(ring)
		var delay: float = float(rd[3])
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2.ONE * (float(rd[2]) / 16.0), NOVA_EXPAND) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(delay)
		t.tween_property(ring, "modulate:a", 0.0, NOVA_EXPAND).set_delay(delay)
		t.set_parallel(false); t.tween_callback(ring.queue_free)
	_spawn_light(center, Color(0.65, 1.0, 0.7), 6.0, 7.0)

func _spawn_particles(center: Vector2) -> void:
	var grad := Gradient.new(); grad.set_color(0, Color(0.8, 1.0, 0.85, 1.0)); grad.set_color(1, Color(0.5, 0.9, 1.0, 0.0))
	var cramp := GradientTexture1D.new(); cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 30.0
	pm.direction = Vector3(0.0, -1.0, 0.0); pm.spread = 180.0
	pm.initial_velocity_min = 300.0; pm.initial_velocity_max = 650.0
	pm.gravity = Vector3.ZERO; pm.scale_min = 1.0; pm.scale_max = 3.0; pm.color_ramp = cramp
	var p := GPUParticles2D.new(); add_child(p)
	p.global_position = center; p.z_index = 6
	p.texture = _make_circ_tex(); p.process_material = pm
	p.amount = 60; p.lifetime = 0.55; p.one_shot = true; p.explosiveness = 0.90; p.emitting = true
	var pmat := CanvasItemMaterial.new(); pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; p.material = pmat
	var t := create_tween(); t.tween_interval(0.85); t.tween_callback(p.queue_free)

func _apply_aoe(attacker: Node, arena: Node, center: Vector2, dmg: int, kid: String) -> void:
	if not arena or not arena.has_method("get_all_alive_avatars"): return
	var my_team := int(attacker.get("_team") if is_instance_valid(attacker) else 1)
	for av in arena.get_all_alive_avatars():
		if av.get("_team") == my_team: continue
		if av.global_position.distance_to(center) > AOE_RADIUS: continue
		if av.has_method("take_damage"): av.take_damage(dmg, kid)
		if av.has_method("stun"):       av.stun(STUN_SECS)

func _make_ring_line(width: float, col: Color, radius: float) -> Line2D:
	var ring := Line2D.new(); ring.width = width; ring.default_color = col; ring.closed = true; ring.antialiased = true
	for i in 24: ring.add_point(Vector2.from_angle(float(i) / 24.0 * TAU) * radius)
	return ring

func _make_circ_tex() -> ImageTexture:
	const S := 8; var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c := Vector2(S * 0.5, S * 0.5)
	for y in S:
		for x in S:
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(c) / (S * 0.5), 0.0, 1.0)))
	return ImageTexture.create_from_image(img)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.60); t.tween_callback(light.queue_free)
