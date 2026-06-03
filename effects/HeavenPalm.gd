extends Node2D
# T4b Team A — giant white chi shockwave ring, ×5, 400 px AoE, knockback 300 px

const DMG_FACTOR  := 5.0
const AOE_RADIUS  := 400.0
const KB_FORCE    := 300.0
const RING_TIME   := 0.45

const PALM_TEX := preload("res://effects/textures/heaven_palm.png")

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
	tw.tween_interval(0.20)   # brief wind-up
	tw.tween_callback(func():
		_spawn_palm_rings(global_position)
		_spawn_screen_flash()
		_apply_aoe(attacker, arena, global_position, dmg, kid)
		if arena and arena.has_method("screen_shake"):
			arena.screen_shake(0.40, 12.0)
	)
	tw.tween_interval(RING_TIME + 1.05)
	tw.tween_callback(queue_free)

func _spawn_charge(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Converging white particles toward attacker
	var grad := Gradient.new(); grad.set_color(0, Color(0.8, 1.0, 0.85, 0.9)); grad.set_color(1, Color(0.5, 0.9, 1.0, 0.0))
	var cramp := GradientTexture1D.new(); cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 110.0
	pm.direction = Vector3(0.0, 1.0, 0.0); pm.spread = 180.0
	pm.initial_velocity_min = 220.0; pm.initial_velocity_max = 380.0
	pm.gravity = Vector3.ZERO; pm.scale_min = 0.8; pm.scale_max = 2.2; pm.color_ramp = cramp
	var p := GPUParticles2D.new(); add_child(p)
	p.global_position = pos; p.z_index = 5
	p.texture = _make_circ_tex(); p.process_material = pm
	p.amount = 35; p.lifetime = 0.22; p.one_shot = true; p.explosiveness = 0.75; p.emitting = true
	var pmat := CanvasItemMaterial.new(); pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; p.material = pmat
	var t := create_tween(); t.tween_interval(0.45); t.tween_callback(p.queue_free)

func _spawn_palm_rings(center: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# 4 rings expanding outward at different speeds / widths
	var ring_defs: Array = [
		[28.0, Color(0.7, 0.98, 1.0, 0.13), 1.12],
		[14.0, Color(0.88, 1.0, 0.92, 0.40), 1.05],
		[ 5.0, Color(1.00, 1.00, 1.00, 0.80), 1.00],
		[ 1.5, Color(0.95, 0.88, 0.40, 1.00), 0.95],
	]
	for rd: Array in ring_defs:
		var ring := _make_ring_line(float(rd[0]), rd[1], 16.0)
		ring.global_position = center; ring.material = mat; add_child(ring)
		var target_scale := AOE_RADIUS * float(rd[2]) / 16.0
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2.ONE * target_scale, RING_TIME) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, RING_TIME)
		t.set_parallel(false); t.tween_callback(ring.queue_free)
	# Palm-print sprite — scales in from center, fades out
	var sp := Sprite2D.new(); add_child(sp)
	sp.texture = PALM_TEX; sp.global_position = center; sp.z_index = 6; sp.material = mat
	const DISPLAY_PX := 700.0  # desired pixel size on screen
	var base_scale := DISPLAY_PX / float(PALM_TEX.get_width())
	sp.scale = Vector2.ZERO
	var sp_tw := sp.create_tween()
	sp_tw.tween_property(sp, "scale", Vector2.ONE * base_scale, 0.18) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	sp_tw.tween_interval(0.30)  # hold at full size
	sp_tw.tween_property(sp, "modulate:a", 0.0, 0.70)
	sp_tw.tween_callback(sp.queue_free)
	_spawn_light(center, Color(0.75, 1.0, 0.65), 5.0, 5.5)

func _spawn_screen_flash() -> void:
	var cl := CanvasLayer.new(); cl.layer = 16; add_child(cl)
	var rect := ColorRect.new(); rect.color = Color(1.0, 1.0, 1.0, 0.0)
	rect.size = Vector2(1920, 1080); cl.add_child(rect)
	var t := rect.create_tween()
	t.tween_property(rect, "color:a", 0.28, 0.06)
	t.tween_property(rect, "color:a", 0.0,  0.30)
	t.tween_callback(cl.queue_free)

func _apply_aoe(attacker: Node, arena: Node, center: Vector2, dmg: int, kid: String) -> void:
	if not arena or not arena.has_method("get_all_alive_avatars"): return
	var my_team := int(attacker.get("_team") if is_instance_valid(attacker) else 1)
	for av in arena.get_all_alive_avatars():
		if av.get("_team") == my_team: continue
		var dist: float = (av as Node2D).global_position.distance_to(center)
		if dist > AOE_RADIUS: continue
		if av.has_method("take_damage"): av.take_damage(dmg, kid)
		if av.has_method("knockback"):
			var dir: Vector2 = ((av as Node2D).global_position - center).normalized()
			if dir.length_squared() < 0.01: dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
			av.knockback(dir * KB_FORCE)

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
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.45); t.tween_callback(light.queue_free)
