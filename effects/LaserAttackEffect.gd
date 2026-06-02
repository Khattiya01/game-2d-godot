extends Node2D

# ── Core timing ───────────────────────────────────────────────────────────────
const DMG_FACTOR      : float = 0.75
const TICK_INTERVAL   : float = 0.75
const BEAM_DURATION   : float = 3.0

# ── Impact PointLight2D ───────────────────────────────────────────────────────
const LIGHT_ENERGY_BASE  := 1.2
const LIGHT_ENERGY_PULSE := 4.5
const LIGHT_FADE_TIME    := 0.28
const LIGHT_SCALE        := 2.8
const LIGHT_COL          := Color(0.3, 0.85, 1.0, 1.0)

# ── Origin ring ───────────────────────────────────────────────────────────────
const ORIGIN_RING_RADIUS := 14.0
const ORIGIN_RING_W      := 3.0

# ── Impact sparks ─────────────────────────────────────────────────────────────
const SPARK_COUNT := 18

# ── Beam shader: energy wave flowing attacker → target ────────────────────────
const BEAM_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float speed      : hint_range(0.0, 20.0) = 9.0;
uniform float wave_count : hint_range(1.0, 60.0) = 18.0;
void fragment() {
    float wave = sin(UV.x * wave_count - TIME * speed) * 0.35 + 0.65;
    COLOR = vec4(COLOR.rgb, COLOR.a * wave);
}
"""

# ── Chromatic aberration: fires once on beam start ────────────────────────────
const CHROMA_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float strength : hint_range(0.0, 12.0) = 4.0;
uniform float alpha    : hint_range(0.0,  1.0) = 1.0;
void fragment() {
    float off = strength / 1920.0;
    float r = texture(screen_texture, SCREEN_UV + vec2(off, 0.0)).r;
    float g = texture(screen_texture, SCREEN_UV).g;
    float b = texture(screen_texture, SCREEN_UV - vec2(off, 0.0)).b;
    COLOR = vec4(r, g, b, alpha);
}
"""

# ── State ─────────────────────────────────────────────────────────────────────
var _attacker: Node = null
var _target: Node = null
var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _active: bool = false
var _finishing: bool = false
var _on_complete: Callable = Callable()
var _damage_mult: float = 1.0
var _base_dmg: int = 10

# ── Visual nodes ──────────────────────────────────────────────────────────────
var _beam_outer: Line2D         # wide glow + energy-wave shader
var _beam_mid: Line2D           # medium additive glow
var _beam_core: Line2D          # sharp bright core
var _impact_light: PointLight2D # pulses on every damage tick
var _impact_sparks: Node2D      # continuous spark particles at impact
var _origin_ring: Line2D        # pulsing ring at attacker origin
var _origin_ring_tween: Tween   # kept to kill on finish
var _light_tex: GradientTexture2D

@onready var sfx: AudioStreamPlayer2D = $SFX

# ── Setup ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_light_tex = _make_light_texture()
	_build_beams()
	_build_impact_light()
	_build_impact_sparks()
	_build_origin_ring()

func _build_beams() -> void:
	# Outer: wide glow with animated energy-wave shader
	_beam_outer = Line2D.new()
	_beam_outer.width = 10.0
	_beam_outer.default_color = Color(0.3, 0.9, 1.0, 0.35)
	_beam_outer.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_outer.end_cap_mode   = Line2D.LINE_CAP_ROUND
	var shdr_mat := ShaderMaterial.new()
	var shdr := Shader.new()
	shdr.code = BEAM_SHADER
	shdr_mat.shader = shdr
	_beam_outer.material = shdr_mat
	add_child(_beam_outer)

	# Mid: soft additive glow
	_beam_mid = Line2D.new()
	_beam_mid.width = 5.0
	_beam_mid.default_color = Color(0.5, 0.95, 1.0, 0.7)
	_beam_mid.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_mid.end_cap_mode   = Line2D.LINE_CAP_ROUND
	var mid_mat := CanvasItemMaterial.new()
	mid_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam_mid.material = mid_mat
	add_child(_beam_mid)

	# Core: thin sharp white line
	_beam_core = Line2D.new()
	_beam_core.width = 1.8
	_beam_core.default_color = Color(0.9, 0.98, 1.0, 1.0)
	_beam_core.begin_cap_mode = Line2D.LINE_CAP_ROUND
	_beam_core.end_cap_mode   = Line2D.LINE_CAP_ROUND
	var core_mat := CanvasItemMaterial.new()
	core_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_beam_core.material = core_mat
	add_child(_beam_core)

func _build_impact_light() -> void:
	_impact_light = PointLight2D.new()
	_impact_light.color = LIGHT_COL
	_impact_light.energy = 0.0
	_impact_light.texture_scale = LIGHT_SCALE
	_impact_light.texture = _light_tex
	add_child(_impact_light)

func _build_impact_sparks() -> void:
	_impact_sparks = Node2D.new()
	var p := GPUParticles2D.new()
	p.amount = SPARK_COUNT
	p.lifetime = 0.45
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.emitting = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 4.0
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 120.0
	pm.initial_velocity_min = 40.0
	pm.initial_velocity_max = 130.0
	pm.gravity = Vector3(0.0, 80.0, 0.0)
	pm.scale_min = 1.5
	pm.scale_max = 3.5
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.3, Color(0.4, 0.85, 1.0, 0.9))
	grad.add_point(1.0, Color(0.1, 0.5,  1.0, 0.0))
	var grad_tex := GradientTexture1D.new()
	grad_tex.gradient = grad
	pm.color_ramp = grad_tex
	p.process_material = pm
	var cim := CanvasItemMaterial.new()
	cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = cim
	_impact_sparks.add_child(p)
	add_child(_impact_sparks)

func _build_origin_ring() -> void:
	_origin_ring = Line2D.new()
	_origin_ring.width = ORIGIN_RING_W
	_origin_ring.default_color = Color(0.4, 0.9, 1.0, 0.8)
	_origin_ring.closed = true
	var segments := 20
	for i in segments:
		var angle := float(i) / float(segments) * TAU
		_origin_ring.add_point(Vector2(cos(angle), sin(angle)) * ORIGIN_RING_RADIUS)
	var cim := CanvasItemMaterial.new()
	cim.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_origin_ring.material = cim
	_origin_ring.modulate.a = 0.0
	add_child(_origin_ring)

func _make_light_texture() -> GradientTexture2D:
	var tex := GradientTexture2D.new()
	tex.fill      = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to   = Vector2(1.0, 0.5)
	tex.width  = 128
	tex.height = 128
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	grad.add_point(0.3, Color(0.5, 0.9, 1.0, 0.5))
	grad.add_point(1.0, Color(0.0, 0.0, 0.0, 0.0))
	tex.gradient = grad
	return tex

# ── Fire ──────────────────────────────────────────────────────────────────────

func fire(effect_data: Dictionary) -> void:
	_attacker      = effect_data.get("attacker", null)
	_target        = effect_data.get("target", null)
	_on_complete   = effect_data.get("on_complete", Callable())
	_damage_mult   = effect_data.get("damage_mult", 1.0)
	_base_dmg      = int(effect_data.get("base_dmg", 10))

	if _attacker and is_instance_valid(_attacker):
		global_position = _attacker.global_position
	else:
		global_position = effect_data.get("from_pos", Vector2.ZERO)

	_active     = true
	_elapsed    = 0.0
	_tick_timer = 0.0

	# Fade in impact light
	var tw := create_tween()
	tw.tween_property(_impact_light, "energy", LIGHT_ENERGY_BASE, 0.15)

	# Start impact sparks
	for child in _impact_sparks.get_children():
		if child is GPUParticles2D:
			child.emitting = true

	# Origin ring fade-in + looping pulse
	_origin_ring.modulate.a = 0.0
	var ring_tw := create_tween()
	ring_tw.tween_property(_origin_ring, "modulate:a", 1.0, 0.12)
	_origin_ring_tween = _origin_ring.create_tween().set_loops()
	_origin_ring_tween.tween_property(_origin_ring, "scale", Vector2.ONE * 1.45, TICK_INTERVAL * 0.4) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_origin_ring_tween.tween_property(_origin_ring, "scale", Vector2.ONE * 1.0,  TICK_INTERVAL * 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

	# Chromatic aberration flash on beam start
	_spawn_chroma_flash()
	sfx.play()

# ── Per-frame ─────────────────────────────────────────────────────────────────

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed    += delta
	_tick_timer += delta

	if not _target or not is_instance_valid(_target):
		_finish()
		return

	if _attacker and is_instance_valid(_attacker):
		global_position = _attacker.global_position

	var end_local := (_target as Node2D).global_position - global_position

	for line: Line2D in [_beam_outer, _beam_mid, _beam_core]:
		line.clear_points()
		line.add_point(Vector2.ZERO)
		line.add_point(end_local)

	_impact_light.position  = end_local
	_impact_sparks.position = end_local

	if _tick_timer >= TICK_INTERVAL:
		_tick_timer -= TICK_INTERVAL
		_apply_damage()
		_pulse_impact_light()

	if _elapsed >= BEAM_DURATION:
		_finish()

func _apply_damage() -> void:
	if not _target or not is_instance_valid(_target):
		return
	if not _target.has_method("take_damage"):
		return
	var kid := str(_attacker.get("player_id")) if _attacker and is_instance_valid(_attacker) else ""
	_target.take_damage(maxi(1, int(float(_base_dmg) * DMG_FACTOR * _damage_mult)), kid)

func _pulse_impact_light() -> void:
	_impact_light.energy = LIGHT_ENERGY_PULSE
	var tw := create_tween()
	tw.tween_property(_impact_light, "energy", LIGHT_ENERGY_BASE, LIGHT_FADE_TIME)

# ── Screen effect ─────────────────────────────────────────────────────────────

func _spawn_chroma_flash() -> void:
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
	mat.set_shader_parameter("strength", 4.0)
	mat.set_shader_parameter("alpha", 1.0)
	rect.material = mat
	cl.add_child(rect)
	var tw := create_tween()
	tw.tween_method(
		func(v: float) -> void: mat.set_shader_parameter("alpha", v),
		1.0, 0.0, 0.08
	)
	tw.tween_callback(cl.queue_free)

# ── Finish ────────────────────────────────────────────────────────────────────

func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	_active = false

	for line: Line2D in [_beam_outer, _beam_mid, _beam_core]:
		line.clear_points()

	if is_instance_valid(_impact_light):
		_impact_light.energy = 0.0

	for child in _impact_sparks.get_children():
		if child is GPUParticles2D:
			child.emitting = false

	if _origin_ring_tween:
		_origin_ring_tween.kill()

	if _on_complete.is_valid():
		_on_complete.call()

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
