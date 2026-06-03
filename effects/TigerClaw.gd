extends Node2D
# T3 Team B — 3 claw-slash marks at target, ×2 per slash, staggered 0.10 s

const DMG_FACTOR  := 2.0
const STAGGER_SEC := 0.10
const CLAW_SCALE  := 0.09  # tune if sprite too big/small

func fire(data: Dictionary) -> void:
	var attacker: Node = data.get("attacker")
	var target:   Node = data.get("target")
	var arena:    Node = data.get("arena")
	var dmult: float   = data.get("damage_mult", 1.0)
	var base: int      = int(data.get("base_dmg", 10))

	if not is_instance_valid(target):
		queue_free(); return

	var kid := str(attacker.get("player_id")) if is_instance_valid(attacker) else ""
	var dmg := maxi(1, int(float(base) * DMG_FACTOR * dmult))

	for i in 3:
		var offset := Vector2(float(i - 1) * 14.0, float(i) * -8.0)
		_slash(target, dmg, kid, float(i) * STAGGER_SEC, offset, arena)

	var cleanup := create_tween()
	cleanup.tween_interval(3 * STAGGER_SEC + 0.6)
	cleanup.tween_callback(queue_free)

func _slash(tgt: Node, dmg: int, kid: String, delay: float, offset: Vector2, arena: Node) -> void:
	var tw := create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_callback(func():
		if not is_instance_valid(tgt): return
		var pos: Vector2 = (tgt as Node2D).global_position + offset
		_draw_slash(pos)
		tgt.take_damage(dmg, kid)
		if arena and arena.has_method("screen_shake"):
			arena.screen_shake(0.08, 3.5)
	)

func _draw_slash(pos: Vector2) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Sprite-based slash mark: swipe in from upper-left, expand, then fade
	var sprite := Sprite2D.new()
	add_child(sprite)
	sprite.texture = preload("res://effects/textures/tiger_claw.png")
	sprite.material = mat
	sprite.z_index = 7
	# Diagonal orientation: claw rakes upper-left → lower-right
	sprite.rotation = deg_to_rad(45.0)
	sprite.scale = Vector2.ZERO
	# Start offset upper-left, swipe to final pos — TRANS_EXPO.EASE_OUT (explosive entry)
	sprite.global_position = pos + Vector2(-20.0, -20.0)
	var t := sprite.create_tween().set_parallel(true)
	t.tween_property(sprite, "scale", Vector2.ONE * CLAW_SCALE, 0.08) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(sprite, "global_position", pos, 0.08) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# Brief recoil wobble: slight counter-rotation then settle
	t.tween_property(sprite, "rotation", deg_to_rad(38.0), 0.07).set_delay(0.08) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(sprite, "rotation", deg_to_rad(45.0), 0.07).set_delay(0.15) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Fade out after hold
	t.tween_property(sprite, "modulate:a", 0.0, 0.28).set_delay(0.14)
	t.set_parallel(false); t.tween_callback(sprite.queue_free)
	# Blood-red PointLight2D flash
	_spawn_light(pos, Color(0.9, 0.05, 0.1), 3.0, 1.8)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.25); t.tween_callback(light.queue_free)
