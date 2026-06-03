extends Node2D
# T2 Team A — white blade projectile, ×2 dmg

const DMG_FACTOR  := 2.0
const FLY_TIME    := 0.26
const BLADE_SCALE := 0.10  # tune this if sprite too big/small

func fire(data: Dictionary) -> void:
	var attacker: Node = data.get("attacker")
	var target:   Node = data.get("target")
	var arena:    Node = data.get("arena")
	var dmult: float   = data.get("damage_mult", 1.0)
	var base: int      = int(data.get("base_dmg", 10))

	if not is_instance_valid(target):
		queue_free(); return

	var start: Vector2 = attacker.global_position if is_instance_valid(attacker) else (target as Node2D).global_position - Vector2(200, 0)
	var end_pt: Vector2 = target.global_position
	var dir    := (end_pt - start).normalized()
	var kid    := str(attacker.get("player_id")) if is_instance_valid(attacker) else ""

	var blade := _make_blade()
	add_child(blade)
	blade.global_position = start
	blade.rotation = dir.angle() - PI * 0.5

	# Glow pulse — TRANS_SINE looping scale oscillation
	var pulse_tw := blade.create_tween().set_loops()
	pulse_tw.tween_property(blade, "scale", Vector2(1.13, 1.13), 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_tw.tween_property(blade, "scale", Vector2(1.0, 1.0), 0.09) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Rotation wobble — blade drifts ±0.13 rad during flight
	var base_rot := blade.rotation
	var wobble_tw := blade.create_tween()
	wobble_tw.tween_property(blade, "rotation", base_rot + 0.13, FLY_TIME * 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	wobble_tw.tween_property(blade, "rotation", base_rot - 0.09, FLY_TIME * 0.55) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_add_trail(start, end_pt)

	var tw := create_tween()
	tw.tween_property(blade, "global_position", end_pt, FLY_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		pulse_tw.kill()
		wobble_tw.kill()
		if is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(maxi(1, int(float(base) * DMG_FACTOR * dmult)), kid)
		if arena and arena.has_method("screen_shake"):
			arena.screen_shake(0.15, 4.5)
		_add_impact(end_pt)
		blade.queue_free()
	)
	tw.tween_interval(0.4)
	tw.tween_callback(queue_free)

func _make_blade() -> Node2D:
	var root := Node2D.new()
	root.z_index = 6
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://effects/textures/sword_qi_blade.png")
	sprite.material = mat
	sprite.scale = Vector2.ONE * BLADE_SCALE
	root.add_child(sprite)
	# Traveling cyan glow — PointLight2D per toolkit pattern
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.add_point(0.3, Color(0.0, 0.87, 1.0, 0.5))
	g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new()
	light.texture = tex; light.texture_scale = 1.2; light.energy = 1.6
	light.color = Color(0.0, 0.87, 1.0)
	root.add_child(light)
	return root

func _add_trail(s: Vector2, e: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for ld: Array in [[14.0, Color(0.65, 0.95, 1.0, 0.08)], [5.0, Color(0.9, 0.98, 1.0, 0.40)], [1.4, Color(1.0, 1.0, 1.0, 0.85)]]:
		var l := Line2D.new(); add_child(l)
		l.z_index = 4; l.material = mat; l.width = float(ld[0]); l.default_color = ld[1]
		l.add_point(s); l.add_point(e)
		var t := l.create_tween()
		t.tween_property(l, "modulate:a", 0.0, FLY_TIME + 0.10)
		t.tween_callback(l.queue_free)

func _add_impact(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for ang: float in [0.0, PI * 0.25, PI * 0.5, PI * 0.75]:
		for ld: Array in [[15.0, Color(0.8, 0.97, 1.0, 0.14)], [5.5, Color(1.0, 1.0, 1.0, 0.65)], [1.5, Color(1.0, 0.92, 0.5, 1.0)]]:
			var l := Line2D.new(); add_child(l)
			l.global_position = pos; l.z_index = 7; l.material = mat
			l.width = float(ld[0]); l.default_color = ld[1]
			l.add_point(Vector2.from_angle(ang) * -26.0)
			l.add_point(Vector2.from_angle(ang) *  26.0)
			var t := l.create_tween().set_parallel(true)
			t.tween_property(l, "scale", Vector2(1.7, 1.7), 0.20) \
				.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			t.tween_property(l, "modulate:a", 0.0, 0.20)
			t.set_parallel(false); t.tween_callback(l.queue_free)
	_spawn_light(pos, Color(0.85, 1.0, 0.6), 3.2, 2.2)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.30); t.tween_callback(light.queue_free)
