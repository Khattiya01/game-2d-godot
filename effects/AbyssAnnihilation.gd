extends Node2D
# T4d Team B — black void implosion → explosion, ×15, stun 2 s, AoE 450 px

const DMG_FACTOR   := 15.0
const AOE_RADIUS   := 450.0
const STUN_SECS    := 2.0
const PULL_RADIUS  := 300.0
const PULL_FORCE   := 320.0
const PULL_TIME    := 0.45
const EXPLODE_TIME := 0.50

var _attacker: Node = null
var _arena: Node    = null
var _dmg: int       = 0
var _kid: String    = ""
var _elapsed: float = 0.0
var _active: bool   = false

func fire(data: Dictionary) -> void:
	_attacker = data.get("attacker")
	_arena    = data.get("arena")
	var target: Node = data.get("target")
	var dmult: float = data.get("damage_mult", 1.0)
	var base: int    = int(data.get("base_dmg", 10))
	_dmg = maxi(1, int(float(base) * DMG_FACTOR * dmult))
	_kid = str(_attacker.get("player_id")) if is_instance_valid(_attacker) else ""

	if not is_instance_valid(_attacker):
		queue_free(); return

	global_position = target.global_position if is_instance_valid(target) else _attacker.global_position
	_active = true
	_spawn_void_sphere()
	_spawn_screen_dim()

	var tw := create_tween()
	tw.tween_interval(PULL_TIME)
	tw.tween_callback(func():
		_active = false
		_spawn_explosion(global_position)
		_apply_aoe(global_position)
		if _arena and _arena.has_method("screen_shake"):
			_arena.screen_shake(0.55, 18.0)
	)
	tw.tween_interval(EXPLODE_TIME + 0.50)
	tw.tween_callback(queue_free)

func _process(delta: float) -> void:
	if not _active: return
	_elapsed += delta
	if not _arena or not _arena.has_method("get_all_alive_avatars"): return
	var my_team := int(_attacker.get("_team") if is_instance_valid(_attacker) else 1)
	var center  := global_position
	var ramp    := minf(_elapsed / 0.35, 1.0)
	for av in _arena.get_all_alive_avatars():
		if av.get("_team") == my_team: continue
		if av.global_position.distance_to(center) > PULL_RADIUS: continue
		var dir: Vector2 = (center - (av as Node2D).global_position).normalized()
		var vel = av.get("_velocity")
		if vel is Vector2:
			av.set("_velocity", vel + dir * PULL_FORCE * ramp * delta)

func _spawn_void_sphere() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Pulsing black/purple void core
	for ld: Array in [[28.0, Color(0.3, 0.0, 0.5, 0.18)], [12.0, Color(0.55, 0.0, 0.80, 0.40)], [3.5, Color(0.80, 0.10, 1.00, 0.75)]]:
		var ring := Line2D.new(); ring.width = float(ld[0]); ring.default_color = ld[1]
		ring.closed = true; ring.material = mat
		for i in 24: ring.add_point(Vector2.from_angle(float(i) / 24.0 * TAU) * 45.0)
		add_child(ring)
		# Shrinking + rotating pull effect
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2(0.15, 0.15), PULL_TIME).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		t.tween_property(ring, "rotation", -TAU * 1.5, PULL_TIME).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		t.set_parallel(false); t.tween_callback(ring.queue_free)

func _spawn_screen_dim() -> void:
	var cl := CanvasLayer.new(); cl.layer = 16; add_child(cl)
	var rect := ColorRect.new(); rect.color = Color(0.0, 0.0, 0.0, 0.0); rect.size = Vector2(1920, 1080); cl.add_child(rect)
	var t := rect.create_tween()
	t.tween_property(rect, "color:a", 0.42, 0.12)
	t.tween_interval(PULL_TIME - 0.12)
	t.tween_property(rect, "color:a", 0.0,  0.45)
	t.tween_callback(cl.queue_free)

func _spawn_explosion(center: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Dark burst rings expanding outward
	for ld: Array in [
		[32.0, Color(0.22, 0.0, 0.4,  0.12), AOE_RADIUS * 1.25],
		[16.0, Color(0.50, 0.0, 0.78, 0.40), AOE_RADIUS * 1.12],
		[ 7.0, Color(0.72, 0.05, 0.95, 0.65), AOE_RADIUS * 1.00],
		[ 2.0, Color(0.88, 0.35, 1.00, 0.90), AOE_RADIUS * 0.88],
	]:
		var ring := Line2D.new(); ring.width = float(ld[0]); ring.default_color = ld[1]
		ring.closed = true; ring.material = mat
		for i in 24: ring.add_point(Vector2.from_angle(float(i) / 24.0 * TAU) * 14.0)
		ring.global_position = center; add_child(ring)
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2.ONE * (float(ld[2]) / 14.0), EXPLODE_TIME) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, EXPLODE_TIME)
		t.set_parallel(false); t.tween_callback(ring.queue_free)
	# Burst particles
	_spawn_burst_particles(center)
	_spawn_light(center, Color(0.7, 0.0, 1.0), 6.5, 7.5)

func _spawn_burst_particles(center: Vector2) -> void:
	var grad := Gradient.new(); grad.set_color(0, Color(0.75, 0.0, 1.0, 0.95)); grad.set_color(1, Color(0.35, 0.0, 0.55, 0.0))
	var cramp := GradientTexture1D.new(); cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE; pm.emission_sphere_radius = 20.0
	pm.direction = Vector3(0.0, -1.0, 0.0); pm.spread = 180.0
	pm.initial_velocity_min = 280.0; pm.initial_velocity_max = 580.0
	pm.gravity = Vector3.ZERO; pm.scale_min = 1.0; pm.scale_max = 3.2; pm.color_ramp = cramp
	const S := 8; var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var cv := Vector2(S * 0.5, S * 0.5)
	for y in S:
		for x in S:
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(cv) / (S * 0.5), 0.0, 1.0)))
	var p := GPUParticles2D.new(); add_child(p)
	p.global_position = center; p.z_index = 6
	p.texture = ImageTexture.create_from_image(img); p.process_material = pm
	p.amount = 65; p.lifetime = 0.60; p.one_shot = true; p.explosiveness = 0.90; p.emitting = true
	var pmat := CanvasItemMaterial.new(); pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD; p.material = pmat
	var t := create_tween(); t.tween_interval(0.90); t.tween_callback(p.queue_free)

func _apply_aoe(center: Vector2) -> void:
	if not _arena or not _arena.has_method("get_all_alive_avatars"): return
	var my_team := int(_attacker.get("_team") if is_instance_valid(_attacker) else 1)
	for av in _arena.get_all_alive_avatars():
		if av.get("_team") == my_team: continue
		if av.global_position.distance_to(center) > AOE_RADIUS: continue
		if av.has_method("take_damage"): av.take_damage(_dmg, _kid)
		if av.has_method("stun"):       av.stun(STUN_SECS)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.60); t.tween_callback(light.queue_free)
