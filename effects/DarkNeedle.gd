extends Node2D
# T2 Team B — 3-needle spread fan, ×2 total dmg split across hits

const DMG_FACTOR   := 0.67   # ×2 total / 3 needles ≈ 0.67 per needle
const FLY_TIME     := 0.32
const SPREAD_DEG   := 16.0   # ±16° fan
const NEEDLE_SCALE := 0.10 # tune this if sprite too big/small

func fire(data: Dictionary) -> void:
	var attacker: Node = data.get("attacker")
	var target:   Node = data.get("target")
	var arena:    Node = data.get("arena")
	var dmult: float   = data.get("damage_mult", 1.0)
	var base: int      = int(data.get("base_dmg", 10))

	if not is_instance_valid(target):
		queue_free(); return

	var start: Vector2  = attacker.global_position if is_instance_valid(attacker) else (target as Node2D).global_position - Vector2(200, 0)
	var kid    := str(attacker.get("player_id")) if is_instance_valid(attacker) else ""
	var base_dir: Vector2 = ((target as Node2D).global_position - start).normalized()
	var dmg    := maxi(1, int(float(base) * DMG_FACTOR * dmult))

	# Build target list: primary + up to 2 chain targets
	var targets: Array[Node] = [target]
	if arena and arena.has_method("get_nearest_on_team_excluding"):
		var my_team: int = int(attacker.get("_team") if is_instance_valid(attacker) else 1)
		for _i in 2:
			var nxt: Node = arena.get_nearest_on_team_excluding(
				targets[-1].global_position, 3 - my_team, targets)
			if nxt and is_instance_valid(nxt):
				targets.append(nxt)

	for i in 3:
		var angle_offset := (float(i) - 1.0) * deg_to_rad(SPREAD_DEG)
		var needle_dir   := base_dir.rotated(angle_offset)
		var t_node: Node = targets[mini(i, targets.size() - 1)]
		var delay: float = float(i) * 0.07
		_shoot_needle(start, needle_dir, t_node, dmg, kid, delay, arena)

	var cleanup := create_tween()
	cleanup.tween_interval(FLY_TIME + 0.6)
	cleanup.tween_callback(queue_free)

func _shoot_needle(start: Vector2, dir: Vector2, tgt: Node, dmg: int, kid: String, delay: float, arena: Node) -> void:
	var end_pt: Vector2 = (tgt as Node2D).global_position if is_instance_valid(tgt) else start + dir * 400.0
	var perp := dir.orthogonal()

	var needle := _make_needle()
	add_child(needle)
	needle.global_position = start
	needle.rotation = dir.angle() + PI * 0.5

	# Glow pulse — TRANS_SINE looping scale oscillation
	var pulse_tw := needle.create_tween().set_loops()
	pulse_tw.tween_property(needle, "scale", Vector2(1.1, 1.1), 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(needle, "scale", Vector2(1.0, 1.0), 0.07) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var trail := Line2D.new(); add_child(trail)
	trail.z_index = 4; trail.material = mat; trail.width = 2.5; trail.antialiased = true
	trail.default_color = Color(0.75, 0.0, 0.18, 0.55)
	trail.add_point(start); trail.add_point(start)

	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	# Perpendicular vibration — needle wobbles ±2.2px through air
	tw.tween_method(func(t: float) -> void:
		var vib := sin(t * TAU * 7.0) * 2.2
		var pos := start.lerp(end_pt, t) + perp * vib
		needle.global_position = pos
		if trail.get_point_count() >= 2:
			trail.set_point_position(1, pos)
	, 0.0, 1.0, FLY_TIME)
	tw.tween_callback(func():
		pulse_tw.kill()
		if is_instance_valid(tgt) and tgt.has_method("take_damage"):
			tgt.take_damage(dmg, kid)
		_add_needle_impact(end_pt)
		needle.queue_free()
		trail.queue_free()
	)

func _make_needle() -> Node2D:
	var root := Node2D.new()
	root.z_index = 6
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://effects/textures/dark_needle.png")
	sprite.material = mat
	sprite.scale = Vector2.ONE * NEEDLE_SCALE
	root.add_child(sprite)
	# Crimson traveling light — PointLight2D per toolkit pattern
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.3, Color(0.85, 0.0, 0.2, 0.5))
	g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new()
	light.texture = tex; light.texture_scale = 0.9; light.energy = 2.0
	light.color = Color(0.85, 0.0, 0.2)
	root.add_child(light)
	return root

func _add_needle_impact(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 6:
		var ang := float(i) / 6.0 * TAU
		var l := Line2D.new(); add_child(l)
		l.global_position = pos; l.z_index = 6; l.material = mat
		l.width = 3.0; l.default_color = Color(0.9, 0.1, 0.25, 0.7)
		l.add_point(Vector2.ZERO); l.add_point(Vector2.from_angle(ang) * 14.0)
		var t := l.create_tween().set_parallel(true)
		t.tween_property(l, "scale", Vector2(1.5, 1.5), 0.18) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(l, "modulate:a", 0.0, 0.18)
		t.set_parallel(false); t.tween_callback(l.queue_free)
	_spawn_light(pos, Color(0.85, 0.0, 0.25), 2.8, 1.8)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.25); t.tween_callback(light.queue_free)
