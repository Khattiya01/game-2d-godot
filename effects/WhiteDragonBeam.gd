extends Node2D
# T4c Team A — hybrid: dragon head sprite at attacker "breathing" 4-layer beam to target
# ×8 total (3 damage ticks over 1.5 s)

const DMG_FACTOR    := 8.0
const BEAM_DURATION := 1.5
const TICK_COUNT    := 3
const SPRITE_PATH   := "res://effects/textures/white_dragon_head.png"
const MOUTH_OFFSET  := 58.0   # px from sprite center to mouth tip (256px * 0.25 scale ≈ 64px, mouth ~90% of edge)

const BEAM_SHADER := """
shader_type canvas_item;
render_mode blend_add;

uniform float flow_speed   : hint_range(0.0, 30.0) = 18.0;
uniform float wave_density : hint_range(1.0, 40.0) = 12.0;
uniform float noise_freq   : hint_range(1.0, 20.0) = 7.0;
uniform float pulse_speed  : hint_range(0.0, 10.0) = 3.5;

void fragment() {
    // UV.x = along beam (0=mouth, 1=target)  UV.y = across width (0-1)
    float cx = abs(UV.y - 0.5) * 2.0;              // 0=center 1=edge

    // Stronger at mouth, fades toward target
    float origin_fade = mix(1.0, 0.30, UV.x);

    // Slight width pulsation
    float pulse = sin(TIME * pulse_speed) * 0.07 + 0.93;

    // Pseudo-noise distortion on beam edges
    float noise = sin(UV.x * noise_freq * PI + TIME * 5.0)
                * cos(UV.x * noise_freq * 0.6 * PI - TIME * 7.0) * 0.16;
    float cx_n = clamp(cx + noise * cx, 0.0, 1.0) / pulse;

    // Animated energy flowing forward along beam
    float flow = sin(UV.x * wave_density - TIME * flow_speed) * 0.22 + 0.78;

    // Core (white hot center) and glow (cyan) zones
    float core = smoothstep(0.55, 0.0, cx_n);
    float glow = smoothstep(1.0, 0.05, cx_n) * (1.0 - core * 0.6);

    // Color gradient: edge=navy → mid=deep blue → core=white
    vec3 col_edge = vec3(0.02, 0.12, 0.72);
    vec3 col_glow = vec3(0.08, 0.38, 0.95);
    vec3 col_core = vec3(1.00, 1.00, 1.00);
    vec3 beam_col = mix(col_edge, col_glow, glow);
    beam_col      = mix(beam_col, col_core, core);

    // Occasional plasma lightning arcs on beam edges
    float arc = step(0.96, sin(UV.x * 28.0 - TIME * 22.0)
                         * sin(UV.x * 19.0 + TIME * 17.0));
    float arc_zone = smoothstep(0.2, 0.65, cx_n) * smoothstep(1.0, 0.55, cx_n);
    beam_col += vec3(0.15, 0.50, 1.0) * arc * arc_zone;

    float alpha = glow * flow * origin_fade;
    alpha += arc * arc_zone * 0.55 * origin_fade;
    alpha  = clamp(alpha, 0.0, 1.0);

    COLOR = vec4(beam_col * alpha, alpha);
}
"""

var _attacker: Node = null
var _target:   Node = null
var _arena:    Node = null
var _elapsed:    float = 0.0
var _tick_timer: float = 0.0
var _ticks_done: int   = 0
var _active: bool = false
var _dmg:      int    = 0
var _kid:      String = ""
var _tick_dmg: int    = 0
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
	_build_beam()
	_spawn_chroma_flash()
	if _arena and _arena.has_method("screen_shake"):
		_arena.screen_shake(0.20, 6.0)
	_active = true


func _process(delta: float) -> void:
	if not _active: return
	_elapsed += delta; _tick_timer += delta

	if not is_instance_valid(_target) or not is_instance_valid(_attacker):
		_finish(); return

	global_position = (_attacker as Node2D).global_position
	var target_pos := (_target as Node2D).global_position
	var dir := (target_pos - global_position).normalized()

	_orient_head(dir)

	# Beam starts from mouth, ends at target (local coords)
	var mouth_local := dir * _mouth_dist
	var end_local   := target_pos - global_position
	for l in _lines:
		if is_instance_valid(l):
			l.clear_points()
			l.add_point(mouth_local)
			l.add_point(end_local)

	var tick_interval := BEAM_DURATION / float(TICK_COUNT + 1)
	if _tick_timer >= tick_interval and _ticks_done < TICK_COUNT:
		_tick_timer -= tick_interval; _ticks_done += 1
		if is_instance_valid(_target) and _target.has_method("take_damage"):
			_target.take_damage(maxi(1, _tick_dmg), _kid)
		_pulse_light(target_pos)

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
		spr.scale = Vector2(0.20, 0.25)
		_anim_pivot.add_child(spr)
		_mouth_dist = MOUTH_OFFSET
		_attach_breath_particles(_anim_pivot, Vector2(MOUTH_OFFSET, 0))
		_build_dragon_animations(n)
	else:
		# Procedural fallback — pulsing origin ring
		_mouth_dist = 38.0
		var ring := Line2D.new()
		ring.width = 4.0; ring.default_color = Color(0.5, 0.95, 1.0, 0.8)
		ring.closed = true; ring.material = mat
		for i in 20: ring.add_point(Vector2.from_angle(float(i) / 20.0 * TAU) * 18.0)
		n.add_child(ring)
		var tw := ring.create_tween().set_loops()
		tw.tween_property(ring, "scale", Vector2.ONE * 1.5, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(ring, "scale", Vector2.ONE * 1.0, 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return n


func _build_dragon_animations(n: Node2D) -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	# Entry pop → breathing scale loop
	_anim_pivot.scale = Vector2(0.3, 0.3)
	var entry := _anim_pivot.create_tween()
	entry.tween_property(_anim_pivot, "scale", Vector2.ONE, 0.28) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	entry.tween_callback(func():
		if not is_instance_valid(_anim_pivot): return
		var pulse := _anim_pivot.create_tween().set_loops()
		pulse.tween_property(_anim_pivot, "scale", Vector2.ONE * 1.08, 0.50) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(_anim_pivot, "scale", Vector2.ONE, 0.50) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)

	# Head sway ±5° relative to beam direction (dragon bobbing while breathing)
	var sway := _anim_pivot.create_tween().set_loops()
	sway.tween_property(_anim_pivot, "rotation", deg_to_rad(5.0), 0.58) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sway.tween_property(_anim_pivot, "rotation", deg_to_rad(-5.0), 0.58) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Pulsing navy glow ring around head
	var ring := Line2D.new()
	ring.width = 2.5; ring.default_color = Color(0.12, 0.45, 1.0, 0.60)
	ring.closed = true; ring.material = mat
	for i in 20: ring.add_point(Vector2.from_angle(float(i) / 20.0 * TAU) * 40.0)
	n.add_child(ring)
	var ring_tw := ring.create_tween().set_loops()
	ring_tw.tween_property(ring, "scale", Vector2.ONE * 1.30, 0.44) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	ring_tw.tween_property(ring, "scale", Vector2.ONE * 0.92, 0.44) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Energy sparks bursting from head
	var parts := GPUParticles2D.new()
	parts.emitting = true; parts.amount = 14; parts.lifetime = 0.55; parts.one_shot = false
	var pm := ParticleProcessMaterial.new()
	pm.spread = 155.0
	pm.initial_velocity_min = 18.0; pm.initial_velocity_max = 52.0
	pm.scale_min = 2.0; pm.scale_max = 5.0
	var g := Gradient.new()
	g.set_color(0, Color(0.45, 0.82, 1.0, 0.9))
	g.set_color(1, Color(0.06, 0.35, 0.92, 0.0))
	var ct := GradientTexture1D.new(); ct.gradient = g
	pm.color_ramp = ct; parts.process_material = pm
	n.add_child(parts)

	# PointLight2D pulsing (deep blue energy at head)
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var grad := Gradient.new()
	grad.set_color(0, Color(1,1,1,1)); grad.add_point(0.35, Color(0.18,0.50,1.0,0.55)); grad.add_point(1.0, Color(0,0,0,0))
	tex.gradient = grad; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); n.add_child(light)
	light.texture = tex; light.texture_scale = 2.2; light.energy = 3.0; light.color = Color(0.18, 0.50, 1.0)
	var lt := light.create_tween().set_loops()
	lt.tween_property(light, "energy", 5.5, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	lt.tween_property(light, "energy", 2.8, 0.42).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _orient_head(dir: Vector2) -> void:
	if not is_instance_valid(_head_node): return
	# Flip horizontally for leftward beams; apply vertical tilt separately
	var going_left := dir.x < 0
	_head_node.scale.x = -1.0 if going_left else 1.0
	_head_node.rotation = asin(clampf(dir.y, -1.0, 1.0)) * (-1.0 if going_left else 1.0)


func _attach_breath_particles(parent: Node2D, offset: Vector2) -> void:
	var breath := GPUParticles2D.new()
	breath.position = offset
	breath.emitting = true
	breath.amount = 18
	breath.lifetime = 0.20
	breath.one_shot = false
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 16.0
	pm.initial_velocity_min = 90.0
	pm.initial_velocity_max = 180.0
	pm.scale_min = 3.0
	pm.scale_max = 9.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.set_color(1, Color(0.25, 0.75, 1.0, 0.0))
	var ct := GradientTexture1D.new(); ct.gradient = grad
	pm.color_ramp = ct
	breath.process_material = pm
	parent.add_child(breath)


func _build_beam() -> void:
	var layer_defs: Array = [
		[52.0, Color(0.5, 0.9, 1.0, 1.00), true],   # comprehensive shader layer
		[18.0, Color(0.6, 0.96, 1.0, 0.25), false],
		[ 8.0, Color(0.85, 1.0, 1.0, 0.65), false],
		[ 2.2, Color(1.0, 1.0, 1.0, 1.00), false],
	]
	for ld: Array in layer_defs:
		var l := Line2D.new()
		l.width = float(ld[0]); l.default_color = ld[1]
		l.begin_cap_mode = Line2D.LINE_CAP_ROUND; l.end_cap_mode = Line2D.LINE_CAP_ROUND
		if bool(ld[2]):
			var sm := ShaderMaterial.new(); var shdr := Shader.new()
			shdr.code = BEAM_SHADER; sm.shader = shdr; l.material = sm
		else:
			var mat := CanvasItemMaterial.new()
			mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; l.material = mat
		add_child(l); _lines.append(l)


func _spawn_chroma_flash() -> void:
	var cl := CanvasLayer.new(); cl.layer = 17; add_child(cl)
	var rect := ColorRect.new(); rect.size = Vector2(1920, 1080)
	var mat := ShaderMaterial.new(); var shdr := Shader.new()
	shdr.code = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0,12.0) = 5.0;
uniform float alpha : hint_range(0.0,1.0) = 1.0;
void fragment() {
    float off = strength / 1920.0;
    float r = texture(screen_texture, SCREEN_UV + vec2(off, 0.0)).r;
    float g = texture(screen_texture, SCREEN_UV).g;
    float b = texture(screen_texture, SCREEN_UV - vec2(off, 0.0)).b;
    COLOR = vec4(r, g, b, alpha);
}"""
	mat.shader = shdr; mat.set_shader_parameter("strength", 5.0); mat.set_shader_parameter("alpha", 1.0)
	rect.material = mat; cl.add_child(rect)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("alpha", v), 1.0, 0.0, 0.10)
	tw.tween_callback(cl.queue_free)


func _pulse_light(pos: Vector2) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(1,1,1,1)); g.add_point(0.3, Color(0.5,0.95,1.0,0.5)); g.add_point(1.0, Color(0,0,0,0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex
	light.texture_scale = 3.0; light.energy = 5.0; light.color = Color(0.5, 0.95, 1.0)
	var tw := create_tween()
	tw.tween_property(light, "energy", 0.0, 0.30)
	tw.tween_callback(light.queue_free)


func _finish() -> void:
	_active = false
	if is_instance_valid(_head_node):
		create_tween().tween_property(_head_node, "modulate:a", 0.0, 0.20)
	for l in _lines:
		if is_instance_valid(l): l.clear_points()
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)
