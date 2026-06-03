extends Node2D
# T4b Team B — ground crack + dark eruption, ×5, 400 px AoE, knockback 300 px

const DMG_FACTOR  := 5.0
const AOE_RADIUS  := 400.0
const KB_FORCE    := 300.0
const CRACK_TIME  := 0.60
const BURST_DELAY := 0.62

const CRACK_TEX := preload("res://effects/textures/shadow_crack.png")
const CRACK_SHADER := preload("res://effects/shaders/crack_reveal.gdshader")

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

	_spawn_cracks(global_position)  # cracks erupt at target position

	var tw := create_tween()
	tw.tween_interval(BURST_DELAY)
	tw.tween_callback(func():
		_spawn_eruption(global_position)
		_spawn_screen_flash()
		_apply_aoe(attacker, arena, global_position, dmg, kid)
		if arena and arena.has_method("screen_shake"):
			arena.screen_shake(0.42, 13.0)
	)
	tw.tween_interval(0.55)
	tw.tween_callback(queue_free)

func _spawn_cracks(center: Vector2) -> void:
	var sp := Sprite2D.new(); add_child(sp)
	sp.texture = CRACK_TEX; sp.global_position = center
	sp.z_as_relative = false; sp.z_index = -5
	const DISPLAY_PX := 820.0  # covers 400 px AoE radius diameter
	var base_scale := DISPLAY_PX / float(CRACK_TEX.get_width())
	sp.scale = Vector2.ONE * base_scale

	var shader_mat := ShaderMaterial.new()
	shader_mat.shader = CRACK_SHADER
	shader_mat.set_shader_parameter("reveal", 0.0)
	shader_mat.set_shader_parameter("edge_soft", 0.10)
	sp.material = shader_mat

	# Phase 1: reveal from center outward over CRACK_TIME
	var tw := sp.create_tween()
	tw.tween_method(
		func(v: float): shader_mat.set_shader_parameter("reveal", v),
		0.0, 1.0, CRACK_TIME
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Phase 2: hold briefly, then fade before eruption completes
	tw.tween_interval(0.12)
	tw.tween_property(sp, "modulate:a", 0.0, 0.35)
	tw.tween_callback(sp.queue_free)

func _spawn_eruption(center: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# 5 dark energy pillars shooting upward
	for i in 5:
		var offset := Vector2(randf_range(-70.0, 70.0), randf_range(-20.0, 20.0))
		var pos    := center + offset
		var height := randf_range(120.0, 200.0)
		for ld: Array in [[22.0, Color(0.3, 0.0, 0.1, 0.13)], [9.0, Color(0.7, 0.0, 0.2, 0.45)], [3.0, Color(1.0, 0.1, 0.3, 0.85)]]:
			var l := Line2D.new(); add_child(l)
			l.global_position = pos; l.z_index = 5; l.material = mat
			l.width = float(ld[0]); l.default_color = ld[1]
			l.add_point(Vector2(0, 0)); l.add_point(Vector2(0, -height))
			l.scale = Vector2(1.0, 0.0)
			var tw := l.create_tween().set_parallel(true)
			tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT).set_delay(float(i) * 0.04)
			tw.tween_property(l, "modulate:a", 0.0, 0.30).set_delay(0.18 + float(i) * 0.04)
			tw.set_parallel(false); tw.tween_callback(l.queue_free)
	# Dark burst rings
	for ld: Array in [[24.0, Color(0.25, 0.0, 0.08, 0.14)], [10.0, Color(0.6, 0.0, 0.18, 0.48)], [2.5, Color(0.9, 0.15, 0.28, 0.88)]]:
		var ring := _make_ring_line(float(ld[0]), ld[1], 14.0)
		ring.global_position = center; ring.material = mat; add_child(ring)
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2.ONE * (AOE_RADIUS / 14.0), 0.45) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.45)
		t.set_parallel(false); t.tween_callback(ring.queue_free)
	_spawn_light(center, Color(0.8, 0.0, 0.25), 5.5, 5.0)

func _spawn_screen_flash() -> void:
	var cl := CanvasLayer.new(); cl.layer = 16; add_child(cl)
	var rect := ColorRect.new(); rect.color = Color(0.4, 0.0, 0.08, 0.0)
	rect.size = Vector2(1920, 1080); cl.add_child(rect)
	var t := rect.create_tween()
	t.tween_property(rect, "color:a", 0.32, 0.07)
	t.tween_property(rect, "color:a", 0.0,  0.35)
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

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.45); t.tween_callback(light.queue_free)
