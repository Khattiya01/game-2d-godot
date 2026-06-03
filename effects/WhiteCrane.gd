extends Node2D
# T3 Team A — 3 feather arcs, ×2 per feather, staggered 0.08 s

const DMG_FACTOR  := 2.0
const FLY_TIME    := 0.32
const STAGGER_SEC := 0.08
const FEATHER_SCALE := 0.07  # tune if sprite too big/small

func fire(data: Dictionary) -> void:
	var attacker: Node = data.get("attacker")
	var target:   Node = data.get("target")
	var arena:    Node = data.get("arena")
	var dmult: float   = data.get("damage_mult", 1.0)
	var base: int      = int(data.get("base_dmg", 10))

	if not is_instance_valid(target):
		queue_free(); return

	var start: Vector2 = attacker.global_position if is_instance_valid(attacker) else (target as Node2D).global_position - Vector2(200, 0)
	var kid   := str(attacker.get("player_id")) if is_instance_valid(attacker) else ""
	var dmg   := maxi(1, int(float(base) * DMG_FACTOR * dmult))

	for i in 3:
		var spread := (float(i) - 1.0) * deg_to_rad(18.0)
		_shoot_feather(start, target, dmg, kid, float(i) * STAGGER_SEC, spread, arena)

	var cleanup := create_tween()
	cleanup.tween_interval(FLY_TIME + 3 * STAGGER_SEC + 0.5)
	cleanup.tween_callback(queue_free)

func _shoot_feather(start: Vector2, tgt: Node, dmg: int, kid: String, delay: float, spread: float, arena: Node) -> void:
	var feather := _make_feather()
	add_child(feather)
	feather.global_position = start

	# Wing glow pulse — TRANS_SINE looping per toolkit pattern
	var pulse_tw := feather.create_tween().set_loops()
	pulse_tw.tween_property(feather, "scale", Vector2(1.08, 1.08), 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(feather, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)

	tw.tween_method(func(t: float) -> void:
		if not is_instance_valid(tgt): return
		var end_pt: Vector2 = (tgt as Node2D).global_position
		var base_dir := (end_pt - start).normalized().rotated(spread)
		# Arc: midpoint rises perpendicular
		var mid := start.lerp(end_pt, 0.5) + base_dir.orthogonal() * -45.0 * sin(t * PI)
		var pos := start.lerp(mid, t * 2.0) if t < 0.5 else mid.lerp(end_pt, (t - 0.5) * 2.0)
		feather.global_position = pos
		# Wing-flap wobble: ±0.18 rad oscillation 3 cycles during flight
		feather.rotation = base_dir.rotated(spread * 0.5).angle() - PI * 0.5 + sin(t * TAU * 3.0) * 0.18
	, 0.0, 1.0, FLY_TIME)

	tw.tween_callback(func():
		pulse_tw.kill()
		if is_instance_valid(tgt) and tgt.has_method("take_damage"):
			tgt.take_damage(dmg, kid)
		_add_feather_burst(feather.global_position)
		feather.queue_free()
	)

func _make_feather() -> Node2D:
	var root := Node2D.new()
	root.z_index = 6
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Sprite from generated asset
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://effects/textures/white_crane.png")
	sprite.material = mat
	sprite.scale = Vector2.ONE * FEATHER_SCALE
	root.add_child(sprite)
	# Soft cyan-green traveling light — PointLight2D per toolkit pattern
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.3, Color(0.7, 1.0, 0.85, 0.5))
	g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new()
	light.texture = tex; light.texture_scale = 1.4; light.energy = 1.8
	light.color = Color(0.7, 1.0, 0.85)
	root.add_child(light)
	return root

func _add_feather_burst(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Petal lines radiating outward
	for i in 8:
		var ang := float(i) / 8.0 * TAU
		for ld: Array in [[10.0, Color(0.6, 0.95, 1.0, 0.13)], [3.5, Color(0.9, 1.0, 0.85, 0.6)], [1.0, Color(1.0, 1.0, 1.0, 0.9)]]:
			var l := Line2D.new(); add_child(l)
			l.global_position = pos; l.z_index = 7; l.material = mat
			l.width = float(ld[0]); l.default_color = ld[1]
			l.add_point(Vector2.ZERO); l.add_point(Vector2.from_angle(ang) * 22.0)
			var t := l.create_tween().set_parallel(true)
			t.tween_property(l, "scale", Vector2(1.6, 1.6), 0.22) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.tween_property(l, "modulate:a", 0.0, 0.22)
			t.set_parallel(false); t.tween_callback(l.queue_free)
	_spawn_light(pos, Color(0.7, 1.0, 0.6), 2.5, 2.0)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.28); t.tween_callback(light.queue_free)
