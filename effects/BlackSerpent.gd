extends Node2D
# T4c Team B — hybrid: serpent head sprite at attacker + sin-wave beam to target
# ×8 total (3 ticks over 1.5 s) + DoT 20 dmg/s × 3 s

const DMG_FACTOR    := 8.0
const BEAM_DURATION := 1.5
const TICK_COUNT    := 3
const DOT_DPS       := 20
const DOT_DURATION  := 3.0
const DOT_TICK_SEC  := 0.5
const WAVE_FREQ     := 4.0
const WAVE_AMP      := 18.0
# Sprite should face RIGHT — code flips horizontally for leftward beams
const SPRITE_PATH   := "res://effects/textures/black_serpent_head.png"
const MOUTH_OFFSET  := 44.0  # px from sprite center to fang tip (128px * 0.38 scale ≈ 49px, mouth ~90% of edge)

var _attacker: Node = null
var _target:   Node = null
var _arena:    Node = null
var _elapsed:    float = 0.0
var _tick_timer: float = 0.0
var _ticks_done: int   = 0
var _active:     bool  = false
var _dmg:      int    = 0
var _kid:      String = ""
var _tick_dmg: int    = 0
var _draw_timer: float = 0.0
var _lines:      Array[Line2D] = []
var _head_node:  Node2D = null
var _anim_pivot: Node2D = null
var _mouth_dist: float  = 0.0


func fire(data: Dictionary) -> void:
	_attacker = data.get("attacker")
	_target   = data.get("target")
	_arena    = data.get("arena")
	var dmult: float = data.get("damage_mult", 1.0)
	var base:  int   = int(data.get("base_dmg", 10))
	_dmg = maxi(1, int(float(base) * DMG_FACTOR * dmult))
	_tick_dmg = _dmg / TICK_COUNT
	_kid = str(_attacker.get("player_id")) if is_instance_valid(_attacker) else ""

	if not is_instance_valid(_target) or not is_instance_valid(_attacker):
		queue_free(); return

	global_position = (_attacker as Node2D).global_position
	_head_node = _build_head()
	add_child(_head_node)
	_spawn_origin_smoke()
	if _arena and _arena.has_method("screen_shake"):
		_arena.screen_shake(0.18, 5.0)
	_active = true


func _process(delta: float) -> void:
	if not _active: return
	_elapsed += delta; _tick_timer += delta; _draw_timer += delta

	if not is_instance_valid(_target) or not is_instance_valid(_attacker):
		_finish(); return

	global_position = (_attacker as Node2D).global_position
	var target_pos := (_target as Node2D).global_position
	var dir := (target_pos - global_position).normalized()

	_orient_head(dir)

	# Redraw serpentine beam every 0.045 s (flicker ~22 fps)
	if _draw_timer >= 0.045:
		_draw_timer = 0.0
		_redraw_serpent(target_pos, dir)

	var tick_interval := BEAM_DURATION / float(TICK_COUNT + 1)
	if _tick_timer >= tick_interval and _ticks_done < TICK_COUNT:
		_tick_timer -= tick_interval; _ticks_done += 1
		if is_instance_valid(_target) and _target.has_method("take_damage"):
			_target.take_damage(maxi(1, _tick_dmg), _kid)

	if _elapsed >= BEAM_DURATION:
		_finish()


func _build_head() -> Node2D:
	var n := Node2D.new()
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	if SPRITE_PATH != "" and ResourceLoader.exists(SPRITE_PATH):
		_anim_pivot = Node2D.new()
		n.add_child(_anim_pivot)
		var spr := Sprite2D.new()
		spr.texture = load(SPRITE_PATH)
		spr.scale = Vector2(0.10, 0.10)
		_anim_pivot.add_child(spr)
		_mouth_dist = MOUTH_OFFSET
		_build_serpent_animations(n)
	else:
		# Procedural fallback — pulsing smoke ring
		_mouth_dist = 30.0
		var ring := Line2D.new()
		ring.width = 3.5; ring.default_color = Color(0.55, 0.0, 0.80, 0.75)
		ring.closed = true; ring.material = mat
		for i in 18: ring.add_point(Vector2.from_angle(float(i) / 18.0 * TAU) * 16.0)
		n.add_child(ring)
		var tw := ring.create_tween().set_loops()
		tw.tween_property(ring, "scale", Vector2.ONE * 1.4, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(ring, "scale", Vector2.ONE * 1.0, 0.40).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return n


func _build_serpent_animations(n: Node2D) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Entry: rise up + scale pop (งูโผล่ขึ้นมาจากด้านล่าง)
	_anim_pivot.scale = Vector2(0.2, 0.2)
	_anim_pivot.position.y = 20.0
	var entry := _anim_pivot.create_tween().set_parallel(true)
	entry.tween_property(_anim_pivot, "scale", Vector2.ONE, 0.24) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	entry.tween_property(_anim_pivot, "position:y", 0.0, 0.24) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	entry.set_parallel(false)
	entry.tween_callback(func():
		if not is_instance_valid(_anim_pivot): return
		# Side-to-side sway ±8° (งูส่ายหัวขณะโจมตี)
		var sway := _anim_pivot.create_tween().set_loops()
		sway.tween_property(_anim_pivot, "rotation", deg_to_rad(8.0), 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		sway.tween_property(_anim_pivot, "rotation", deg_to_rad(-8.0), 0.32) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

	# Forked tongue periodic flick
	_tongue_loop(n)

	# Venom drip particles (ตกลงล่าง)
	var parts := GPUParticles2D.new()
	parts.emitting = true; parts.amount = 10; parts.lifetime = 0.50; parts.one_shot = false
	var pm := ParticleProcessMaterial.new()
	pm.gravity = Vector3(0, 135, 0)
	pm.spread = 18.0
	pm.initial_velocity_min = 8.0; pm.initial_velocity_max = 24.0
	pm.scale_min = 1.5; pm.scale_max = 3.5
	var g := Gradient.new()
	g.set_color(0, Color(0.52, 0.0, 0.82, 0.9))
	g.set_color(1, Color(0.16, 0.0, 0.32, 0.0))
	var ct := GradientTexture1D.new(); ct.gradient = g
	pm.color_ramp = ct; parts.process_material = pm
	n.add_child(parts)

	# Purple glow ring pulse
	var ring := Line2D.new()
	ring.width = 2.0; ring.default_color = Color(0.48, 0.0, 0.80, 0.55)
	ring.closed = true; ring.material = mat
	for i in 18: ring.add_point(Vector2.from_angle(float(i) / 18.0 * TAU) * 30.0)
	n.add_child(ring)
	var ring_tw := ring.create_tween().set_loops()
	ring_tw.tween_property(ring, "scale", Vector2.ONE * 1.32, 0.36) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ring_tw.tween_property(ring, "scale", Vector2.ONE * 0.88, 0.36) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# PointLight2D purple pulse
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1,1,1,1)); grad.add_point(0.3, Color(0.55,0.0,0.9,0.5)); grad.add_point(1.0, Color(0,0,0,0))
	tex.gradient = grad; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); n.add_child(light)
	light.texture = tex; light.texture_scale = 2.0; light.energy = 2.5; light.color = Color(0.55, 0.0, 0.9)
	var lt := light.create_tween().set_loops()
	lt.tween_property(light, "energy", 5.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lt.tween_property(light, "energy", 2.0, 0.36).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _tongue_loop(parent: Node2D) -> void:
	if not _active or not is_instance_valid(parent): return
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var tongue := Node2D.new()
	# Mouth tip in head_node local space: sprite faces LEFT → mouth at -X
	tongue.position = Vector2(-MOUTH_OFFSET * 0.55, 0.0)
	parent.add_child(tongue)
	for side: int in [-1, 1]:
		var seg := Line2D.new()
		seg.width = 1.8; seg.default_color = Color(0.78, 0.18, 1.0, 0.95)
		seg.material = mat
		seg.add_point(Vector2.ZERO)
		seg.add_point(Vector2(-13.0, float(side) * 6.0))
		tongue.add_child(seg)
	var tw := tongue.create_tween()
	tw.tween_interval(0.14)
	tw.tween_property(tongue, "modulate:a", 0.0, 0.10)
	tw.tween_callback(tongue.queue_free)
	get_tree().create_timer(randf_range(0.38, 0.65)).timeout.connect(func():
		_tongue_loop(parent)
	)


func _orient_head(dir: Vector2) -> void:
	if not is_instance_valid(_head_node): return
	# Sprite faces LEFT (native angle=π); +PI aligns mouth with dir correctly
	_head_node.rotation = dir.angle() + PI


func _redraw_serpent(target_pos: Vector2, dir: Vector2) -> void:
	for child in get_children():
		if child is Line2D: child.free()

	var start  := dir * _mouth_dist
	var end_pt := target_pos - global_position
	var perp   := (end_pt - start).orthogonal().normalized()

	const SEGMENTS := 20
	var pts: Array[Vector2] = []
	for i in SEGMENTS + 1:
		var t_val  := float(i) / float(SEGMENTS)
		var base_pt := start.lerp(end_pt, t_val)
		var disp   := sin(t_val * WAVE_FREQ * PI + _elapsed * 8.0) * WAVE_AMP * sin(t_val * PI)
		pts.append(base_pt + perp * disp)

	_make_bolt(pts, 22.0, Color(0.25, 0.0, 0.45, 0.08))
	_make_bolt(pts, 10.0, Color(0.55, 0.0, 0.80, 0.30))
	_make_bolt(pts,  4.0, Color(0.78, 0.10, 1.00, 0.65))
	_make_bolt(pts,  1.4, Color(0.92, 0.55, 1.00, 1.00))


func _make_bolt(pts: Array[Vector2], width: float, col: Color) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var l := Line2D.new(); l.width = width; l.default_color = col; l.material = mat
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND; l.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(l)
	for p in pts: l.add_point(p)


func _spawn_origin_smoke() -> void:
	if not is_instance_valid(_attacker): return
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for i in 4:
		var puff := Polygon2D.new(); add_child(puff); puff.z_index = 4; puff.material = mat
		puff.global_position = (_attacker as Node2D).global_position + Vector2(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0))
		var r := randf_range(7.0, 12.0)
		var pts := PackedVector2Array()
		for j in 6: pts.append(Vector2.from_angle(float(j) / 6.0 * TAU + randf_range(-0.3, 0.3)) * r)
		puff.polygon = pts; puff.color = Color(0.4, 0.0, 0.6, 0.45)
		var tw := puff.create_tween().set_parallel(true)
		tw.tween_property(puff, "scale", Vector2(2.5, 2.5), 0.30).set_delay(float(i) * 0.025).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		tw.tween_property(puff, "modulate:a", 0.0, 0.30).set_delay(float(i) * 0.025)
		tw.set_parallel(false); tw.tween_callback(puff.queue_free)


func _finish() -> void:
	_active = false
	if is_instance_valid(_head_node):
		create_tween().tween_property(_head_node, "modulate:a", 0.0, 0.20)
	if is_instance_valid(_target):
		_apply_dot(_target, _kid)
	for child in get_children():
		if child is Line2D: child.free()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.tween_callback(queue_free)


func _apply_dot(tgt: Node, kid: String) -> void:
	var ticks := int(DOT_DURATION / DOT_TICK_SEC)
	var dot_dmg := maxi(1, int(float(DOT_DPS) * DOT_TICK_SEC))
	for i in ticks:
		get_tree().create_timer(float(i + 1) * DOT_TICK_SEC).timeout.connect(func():
			if is_instance_valid(tgt) and tgt.has_method("take_damage"):
				tgt.take_damage(dot_dmg, kid)
		)
