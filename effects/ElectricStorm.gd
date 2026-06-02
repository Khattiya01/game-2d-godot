extends Node2D
class_name ElectricStorm

# ── Timing ────────────────────────────────────────────────────────────────────
const FADE_IN         := 0.4
const FADE_OUT        := 1.2

# ── Player-count scaling bounds ───────────────────────────────────────────────
const SCALE_N_MIN       := 2
const SCALE_N_MAX       := 30
const DURATION_MAX      := 12.0   # n=2  → 12 s
const DURATION_MIN      := 4.0    # n=30 → 4 s
const STRIKE_PCT_MIN    := 0.06   # n=2  → 6 %
const STRIKE_PCT_MAX    := 0.18   # n=30 → 18 %
const CHAIN_PCT_MIN     := 0.03
const CHAIN_PCT_MAX     := 0.10
const INTERVAL_MAX      := 0.30   # n=2  → slower strikes
const INTERVAL_MIN      := 0.16   # n=30 → faster strikes

# ── Damage (% of target's current HP) ────────────────────────────────────────
const MIN_DAMAGE      := 10      # floor so low-HP avatars still feel it
const HIT_RADIUS      := 75.0
const CHAIN_RADIUS    := 120.0
const STUN_CHANCE     := 0.25
const STUN_DURATION   := 1.0

# ── Bolt geometry ─────────────────────────────────────────────────────────────
const BOLT_SEGMENTS   := 12
const BOLT_MAX_DISP   := 38.0
const BOLT_AURA_W     := 16.0
const BOLT_GLOW_W     := 6.0
const BOLT_CORE_W     := 1.8
const BOLT_AURA_COL   := Color(0.05, 0.35, 1.0,  0.18)
const BOLT_GLOW_COL   := Color(0.30, 0.70, 1.0,  0.65)
const BOLT_CORE_COL   := Color(0.90, 0.97, 1.0,  1.00)
const CHAIN_GLOW_COL  := Color(0.70, 0.30, 1.0,  0.55)
const CHAIN_CORE_COL  := Color(0.90, 0.65, 1.0,  1.00)

# ── PointLight2D ──────────────────────────────────────────────────────────────
const LIGHT_ENERGY    := 3.5
const LIGHT_SCALE     := 3.2
const LIGHT_FADE      := 0.28
const LIGHT_COL       := Color(0.4, 0.75, 1.0, 1.0)

# ── Ambient particles ─────────────────────────────────────────────────────────
const AMBIENT_COUNT   := 70

var _arena: Node = null
var _elapsed: float = 0.0
var _strike_timer: float = 0.0
var _active: bool = false
var _overlay_rect: ColorRect = null
var _ambient_cl: CanvasLayer = null
var _light_tex: GradientTexture2D = null
var _sfx_ambient: AudioStreamPlayer = null
var _sfx_strike: AudioStreamPlayer = null
var _strike_playback: AudioStreamPlaybackPolyphonic = null
var _strike_streams: Array[AudioStream] = []

# ── Runtime-scaled values (set by _compute_scale) ────────────────────────────
var _storm_duration   := 5.0
var _strike_pct       := 0.15
var _chain_pct        := 0.08
var _strike_interval  := 0.20

# ── Shader sources ────────────────────────────────────────────────────────────

const OVERLAY_SHADER := """
shader_type canvas_item;
void fragment() {
    float n  = sin(UV.x * 6.0 + TIME * 0.60) * cos(UV.y * 4.0 + TIME * 0.40);
    float n2 = cos(UV.x * 3.0 + UV.y * 5.0  + TIME * 0.85);
    float cloud = (n * 0.5 + 0.5) * (n2 * 0.5 + 0.5);
    COLOR = vec4(0.02, 0.05, 0.18, cloud * 0.38 + 0.10);
}
"""

const CHROMA_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 12.0) = 5.0;
uniform float alpha    : hint_range(0.0,  1.0) = 1.0;
void fragment() {
    float off = strength / 1920.0;
    float r = texture(screen_texture, SCREEN_UV + vec2(off, 0.0)).r;
    float g = texture(screen_texture, SCREEN_UV).g;
    float b = texture(screen_texture, SCREEN_UV - vec2(off, 0.0)).b;
    COLOR = vec4(r, g, b, alpha);
}
"""

# ── Entry point ───────────────────────────────────────────────────────────────

func _compute_scale(n: int) -> void:
	var t := sqrt(clampf(float(n - SCALE_N_MIN) / float(SCALE_N_MAX - SCALE_N_MIN), 0.0, 1.0))
	_storm_duration  = lerpf(DURATION_MAX,   DURATION_MIN,   t)
	_strike_pct      = lerpf(STRIKE_PCT_MIN,  STRIKE_PCT_MAX,  t)
	_chain_pct       = lerpf(CHAIN_PCT_MIN,   CHAIN_PCT_MAX,   t)
	_strike_interval = lerpf(INTERVAL_MAX,    INTERVAL_MIN,    t)

func fire(data: Dictionary) -> void:
	_arena = data.get("arena")
	var n := 2
	if _arena and _arena.has_method("get_all_alive_avatars"):
		n = maxi(SCALE_N_MIN, _arena.get_all_alive_avatars().size())
	_compute_scale(n)
	_light_tex = _make_light_texture()
	_setup_dark_overlay()
	_setup_ambient_particles()
	_setup_sfx()
	_show_announcement()
	_active = true

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_strike_timer += delta
	if _strike_timer >= _strike_interval:
		_strike_timer -= _strike_interval
		_do_strike()
	if _elapsed >= _storm_duration:
		_end_storm()

# ── Atmosphere setup ──────────────────────────────────────────────────────────

func _setup_dark_overlay() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 1
	add_child(cl)
	_overlay_rect = ColorRect.new()
	_overlay_rect.anchors_preset = Control.PRESET_FULL_RECT
	_overlay_rect.size = Vector2(1920, 1080)
	var mat := ShaderMaterial.new()
	var shdr := Shader.new()
	shdr.code = OVERLAY_SHADER
	mat.shader = shdr
	_overlay_rect.material = mat
	_overlay_rect.modulate.a = 0.0
	cl.add_child(_overlay_rect)
	var tw := create_tween()
	tw.tween_property(_overlay_rect, "modulate:a", 1.0, FADE_IN)

func _setup_ambient_particles() -> void:
	_ambient_cl = CanvasLayer.new()
	_ambient_cl.layer = 6
	add_child(_ambient_cl)
	var p := GPUParticles2D.new()
	p.amount = AMBIENT_COUNT
	p.lifetime = 1.6
	p.explosiveness = 0.0
	p.randomness = 0.9
	p.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(960, 540, 0)
	pm.direction = Vector3(1.0, -0.2, 0.0)
	pm.spread = 22.0
	pm.initial_velocity_min = 60.0
	pm.initial_velocity_max = 200.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 1.5
	pm.scale_max = 3.5
	var grad := Gradient.new()
	grad.set_color(0, Color(0.7, 0.9, 1.0, 0.8))
	grad.add_point(0.6, Color(0.3, 0.6, 1.0, 0.4))
	grad.add_point(1.0, Color(0.1, 0.3, 0.8, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	p.process_material = pm
	var cim := CanvasItemMaterial.new()
	cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = cim
	p.position = Vector2(960, 540)
	_ambient_cl.add_child(p)

func _show_announcement() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	var lbl := Label.new()
	lbl.text = "⚡ ELECTRIC STORM ⚡"
	lbl.add_theme_font_size_override("font_size", 54)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.92, 1.0, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.05, 0.2, 0.7, 1.0))
	lbl.add_theme_constant_override("outline_size", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.size = Vector2(1920, 90)
	lbl.position = Vector2(0, 70)
	lbl.modulate.a = 0.0
	cl.add_child(lbl)
	var tw := create_tween()
	tw.tween_property(lbl, "modulate:a", 1.0, 0.25)
	tw.tween_interval(1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.45)

# ── SFX ───────────────────────────────────────────────────────────────────────

func _setup_sfx() -> void:
	_sfx_ambient = AudioStreamPlayer.new()
	var amb: Resource = load("res://assets/sounds/rain_and_thunders_01.mp3").duplicate()
	if amb is AudioStreamMP3:
		(amb as AudioStreamMP3).loop = true
	_sfx_ambient.stream = amb
	add_child(_sfx_ambient)
	_sfx_ambient.play()

	# Polyphonic player — each bolt plays to completion without cutting previous ones
	_strike_streams = [
		load("res://assets/sounds/electric_storm_attack_01.mp3"),
		load("res://assets/sounds/electric_storm_attack_02.mp3"),
	]
	_sfx_strike = AudioStreamPlayer.new()
	var poly := AudioStreamPolyphonic.new()
	poly.polyphony = 6
	_sfx_strike.stream = poly
	add_child(_sfx_strike)
	_sfx_strike.play()
	_strike_playback = _sfx_strike.get_stream_playback() as AudioStreamPlaybackPolyphonic

# ── Per-strike ────────────────────────────────────────────────────────────────

func _do_strike() -> void:
	var x := randf_range(120.0, 1800.0)
	var y := randf_range(220.0, 940.0)
	var impact := Vector2(x, y)
	var top := Vector2(x + randf_range(-120.0, 120.0), -60.0)

	# Pre-flash: sky brightens before bolt (t=0), then bolt + sound hit together (t=0.025s)
	_spawn_screen_flash()

	var tw_pre := create_tween()
	tw_pre.tween_interval(0.025)
	tw_pre.tween_callback(func() -> void:
		if _strike_playback and is_instance_valid(_sfx_strike):
			var s: AudioStream = _strike_streams[randi() % _strike_streams.size()]
			_strike_playback.play_stream(s, 0.0, -3.0)
		_spawn_bolt(top, impact, false)
		_spawn_strike_light(impact)
		_spawn_chromatic_ab()
		_spawn_impact_particles(impact)
	)

	if _arena and _arena.has_method("screen_shake"):
		_arena.screen_shake(0.12, 3.5)

	if not _arena:
		return
	var hit := _find_nearest(impact, HIT_RADIUS, null)
	if not hit:
		return
	var hit_dmg := maxi(MIN_DAMAGE, int(float(hit.get("current_hp")) * _strike_pct))
	hit.take_damage(hit_dmg, "electric_storm")
	if randf() < STUN_CHANCE and hit.has_method("stun"):
		hit.stun(STUN_DURATION)
		_spawn_stun_indicator(hit)
	# Chain to nearest avatar within CHAIN_RADIUS of the hit avatar
	var chain := _find_nearest(hit.global_position, CHAIN_RADIUS, hit)
	if chain:
		_spawn_bolt(hit.global_position, chain.global_position, true)
		var chain_dmg := maxi(MIN_DAMAGE, int(float(chain.get("current_hp")) * _chain_pct))
		chain.take_damage(chain_dmg, "electric_storm")

# ── Bolt visuals ──────────────────────────────────────────────────────────────

func _spawn_bolt(from: Vector2, to: Vector2, is_chain: bool) -> void:
	var nd := Node2D.new()
	add_child(nd)
	var pts := _zigzag(from, to)
	if not is_chain:
		_add_line(nd, pts, BOLT_AURA_W, BOLT_AURA_COL)
		_add_line(nd, pts, BOLT_GLOW_W, BOLT_GLOW_COL)
		_add_line(nd, pts, BOLT_CORE_W, BOLT_CORE_COL)
		for _b in 2:
			var bpts := _branch(pts)
			if bpts.size() > 1:
				_add_line(nd, bpts, 3.5, BOLT_GLOW_COL)
				_add_line(nd, bpts, 1.2, BOLT_CORE_COL)
	else:
		_add_line(nd, pts, 4.0, CHAIN_GLOW_COL)
		_add_line(nd, pts, 1.4, CHAIN_CORE_COL)
	var hold := 0.08 if is_chain else 0.14
	var tw := nd.create_tween()
	tw.tween_interval(hold)
	tw.tween_property(nd, "modulate:a", 0.0, 0.16)
	tw.tween_callback(nd.queue_free)

func _add_line(parent: Node2D, pts: Array[Vector2], w: float, col: Color) -> void:
	var line := Line2D.new()
	line.width = w
	line.default_color = col
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = mat
	for p: Vector2 in pts:
		line.add_point(p)
	parent.add_child(line)

func _zigzag(from: Vector2, to: Vector2) -> Array[Vector2]:
	var dir := to - from
	var perp := Vector2(-dir.normalized().y, dir.normalized().x)
	var pts: Array[Vector2] = [from]
	for i in BOLT_SEGMENTS:
		var t := float(i + 1) / float(BOLT_SEGMENTS + 1)
		var base := from.lerp(to, t)
		var disp := randf_range(-BOLT_MAX_DISP, BOLT_MAX_DISP) * sin(t * PI)
		pts.append(base + perp * disp)
	pts.append(to)
	return pts

func _branch(main_pts: Array[Vector2]) -> Array[Vector2]:
	if main_pts.size() < 4:
		return []
	var idx := randi_range(2, main_pts.size() - 3)
	var root: Vector2 = main_pts[idx]
	var prev: Vector2 = main_pts[idx - 1]
	var nxt: Vector2  = main_pts[mini(idx + 1, main_pts.size() - 1)]
	var dir := (nxt - prev).normalized()
	var length := randf_range(35.0, 80.0)
	var tip := root + dir.rotated(randf_range(-0.7, 0.7)) * length
	var mid := root.lerp(tip, 0.5) + Vector2(
		randf_range(-length * 0.15, length * 0.15),
		randf_range(-length * 0.15, length * 0.15)
	)
	return [root, mid, tip]

# ── PointLight2D flash ────────────────────────────────────────────────────────

func _spawn_strike_light(pos: Vector2) -> void:
	var light := PointLight2D.new()
	light.position = pos
	light.color = LIGHT_COL
	light.energy = LIGHT_ENERGY
	light.texture_scale = LIGHT_SCALE
	light.texture = _light_tex
	add_child(light)
	var tw := create_tween()
	tw.tween_property(light, "energy", 0.0, LIGHT_FADE)
	tw.tween_callback(light.queue_free)

func _make_light_texture() -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	tex.width  = 128
	tex.height = 128
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.3, Color(0.7, 0.85, 1.0, 0.5))
	grad.add_point(1.0, Color(0.0, 0.0, 0.0, 0.0))
	tex.gradient = grad
	return tex

# ── Screen effects ────────────────────────────────────────────────────────────

func _spawn_screen_flash() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 16
	add_child(cl)
	var rect := ColorRect.new()
	rect.color = Color(0.5, 0.75, 1.0, 0.22)
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.size = Vector2(1920, 1080)
	cl.add_child(rect)
	# Brief hold then fade — gives the eye time to register the flash
	var tw := create_tween()
	tw.tween_interval(0.04)
	tw.tween_property(rect, "modulate:a", 0.0, 0.14)
	tw.tween_callback(cl.queue_free)

func _spawn_chromatic_ab() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 17
	add_child(cl)
	var rect := ColorRect.new()
	rect.anchors_preset = Control.PRESET_FULL_RECT
	rect.size = Vector2(1920, 1080)
	var mat := ShaderMaterial.new()
	var shdr := Shader.new()
	shdr.code = CHROMA_SHADER
	mat.shader = shdr
	mat.set_shader_parameter("strength", 5.0)
	mat.set_shader_parameter("alpha", 1.0)
	rect.material = mat
	cl.add_child(rect)
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("alpha", v),
		1.0, 0.0, 0.10
	)
	tw.tween_callback(cl.queue_free)

# ── Impact particles ──────────────────────────────────────────────────────────

func _spawn_impact_particles(pos: Vector2) -> void:
	var nd := Node2D.new()
	nd.position = pos
	add_child(nd)
	var p := GPUParticles2D.new()
	p.amount = 28
	p.lifetime = 0.55
	p.explosiveness = 0.95
	p.one_shot = true
	p.emitting = true
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 8.0
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 180.0
	pm.initial_velocity_min = 90.0
	pm.initial_velocity_max = 280.0
	pm.gravity = Vector3(0.0, 150.0, 0.0)
	pm.scale_min = 2.0
	pm.scale_max = 5.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.3, Color(0.5, 0.8, 1.0, 0.9))
	grad.add_point(1.0, Color(0.2, 0.4, 1.0, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	p.process_material = pm
	var cim := CanvasItemMaterial.new()
	cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = cim
	nd.add_child(p)
	var tw := create_tween()
	tw.tween_interval(0.8)
	tw.tween_callback(nd.queue_free)

# ── Stun indicator (blue stars — matches electric theme) ──────────────────────

func _spawn_stun_indicator(target: Node) -> void:
	var ind := Node2D.new()
	ind.position = Vector2(0.0, -45.0)
	target.add_child(ind)
	var star_cols := [
		Color(0.4, 0.8, 1.0, 1.0),
		Color(0.2, 0.6, 1.0, 1.0),
		Color(0.7, 0.92, 1.0, 1.0),
	]
	for i in 5:
		var star := Polygon2D.new()
		star.color = star_cols[i % star_cols.size()]
		star.polygon = _star_pts(5.5)
		var angle := float(i) / 5.0 * TAU
		star.position = Vector2(cos(angle), sin(angle)) * 18.0
		ind.add_child(star)
	var rot_tw := ind.create_tween().set_loops()
	rot_tw.tween_property(ind, "rotation", TAU, 1.5).set_trans(Tween.TRANS_LINEAR)
	get_tree().create_timer(STUN_DURATION - 0.2).timeout.connect(func() -> void:
		if not is_instance_valid(ind):
			return
		rot_tw.kill()
		var fade := ind.create_tween()
		fade.tween_property(ind, "modulate:a", 0.0, 0.25)
		fade.tween_callback(ind.queue_free)
	)

func _star_pts(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var inner := r * 0.4
	for i in 10:
		var angle := float(i) / 10.0 * TAU - PI * 0.5
		var rad := r if i % 2 == 0 else inner
		pts.append(Vector2(cos(angle), sin(angle)) * rad)
	return pts

# ── Avatar search ─────────────────────────────────────────────────────────────

func _find_nearest(pos: Vector2, radius: float, exclude: Node) -> Node:
	if not _arena or not _arena.has_method("get_all_alive_avatars"):
		return null
	var nearest: Node = null
	var nearest_sq := radius * radius
	for av: Node in _arena.get_all_alive_avatars():
		if av == exclude:
			continue
		var d := (av as Node2D).global_position.distance_squared_to(pos)
		if d < nearest_sq:
			nearest_sq = d
			nearest = av
	return nearest

# ── End ───────────────────────────────────────────────────────────────────────

func _end_storm() -> void:
	_active = false
	if _sfx_ambient and is_instance_valid(_sfx_ambient):
		var tw_amb := create_tween()
		tw_amb.tween_property(_sfx_ambient, "volume_db", -80.0, FADE_OUT)
		tw_amb.tween_callback(_sfx_ambient.stop)
	if _overlay_rect and is_instance_valid(_overlay_rect):
		var tw := create_tween()
		tw.tween_property(_overlay_rect, "modulate:a", 0.0, FADE_OUT)
	if _ambient_cl and is_instance_valid(_ambient_cl):
		for child in _ambient_cl.get_children():
			if child is GPUParticles2D:
				child.emitting = false
	var tw2 := create_tween()
	tw2.tween_interval(FADE_OUT + 0.5)
	tw2.tween_callback(queue_free)
