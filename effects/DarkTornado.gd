extends Node2D
# T4a Team B — pull 150 px then burst, ×3.5 AoE

const DMG_FACTOR  := 3.5
const PULL_RADIUS := 150.0
const AOE_RADIUS  := 200.0
const PULL_FORCE  := 260.0   # px/s²
const PULL_TIME   := 0.65
const EXPLODE_DELAY  := 0.65
const TORNADO_SCALE      := 0.09  # tune if sprite too big/small
const AOE_EXPLODE_SCALE  := 0.42  # tune if AoE explosion sprite too big/small

var _attacker: Node = null
var _arena: Node    = null
var _dmg: int       = 0
var _kid: String    = ""
var _elapsed: float        = 0.0
var _active: bool          = false
var _tornado_sprite: Sprite2D = null

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
	_spawn_spiral()

	var tw := create_tween()
	tw.tween_interval(EXPLODE_DELAY)
	tw.tween_callback(_explode)

func _process(delta: float) -> void:
	if not _active: return
	_elapsed += delta
	if _elapsed >= PULL_TIME: return
	if not _arena or not _arena.has_method("get_all_alive_avatars"): return
	var my_team := int(_attacker.get("_team") if is_instance_valid(_attacker) else 1)
	var center  := global_position
	var ramp    := minf(_elapsed / 0.5, 1.0)
	for av in _arena.get_all_alive_avatars():
		if av.get("_team") == my_team: continue
		if av.global_position.distance_to(center) > PULL_RADIUS: continue
		var dir: Vector2 = (center - (av as Node2D).global_position).normalized()
		var vel = av.get("_velocity")
		if vel is Vector2:
			av.set("_velocity", vel + dir * PULL_FORCE * ramp * delta)

func _spawn_spiral() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Center tornado sprite — spins fast clockwise as pull builds
	var smat := CanvasItemMaterial.new(); smat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_tornado_sprite = Sprite2D.new()
	_tornado_sprite.texture = preload("res://effects/textures/dark_tornado.png")
	_tornado_sprite.material = smat
	_tornado_sprite.z_index = 5
	_tornado_sprite.scale = Vector2.ZERO
	add_child(_tornado_sprite)
	# Scale in (TRANS_EXPO.EASE_OUT) then start looping glow pulse
	var init_tw := _tornado_sprite.create_tween()
	init_tw.tween_property(_tornado_sprite, "scale", Vector2.ONE * TORNADO_SCALE, 0.20) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	init_tw.tween_callback(func():
		if not is_instance_valid(_tornado_sprite): return
		var pulse_tw := _tornado_sprite.create_tween().set_loops()
		pulse_tw.tween_property(_tornado_sprite, "scale", Vector2.ONE * TORNADO_SCALE * 1.10, 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse_tw.tween_property(_tornado_sprite, "scale", Vector2.ONE * TORNADO_SCALE, 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	)
	# Fast clockwise spin — TRANS_LINEAR tornado rotation, 1 turn per 0.35s
	var spin_tw := _tornado_sprite.create_tween().set_loops()
	spin_tw.tween_property(_tornado_sprite, "rotation", -TAU, 0.35).set_trans(Tween.TRANS_LINEAR)
	# PointLight2D purple-magenta vortex core glow per toolkit pattern
	var ltex := GradientTexture2D.new()
	ltex.fill = GradientTexture2D.FILL_RADIAL; ltex.fill_from = Vector2(0.5, 0.5); ltex.fill_to = Vector2(1.0, 0.5)
	var lg := Gradient.new(); lg.set_color(0, Color(1, 1, 1, 1)); lg.add_point(0.3, Color(0.65, 0.0, 1.0, 0.45)); lg.add_point(1.0, Color(0, 0, 0, 0))
	ltex.gradient = lg; ltex.width = 128; ltex.height = 128
	var tlight := PointLight2D.new()
	tlight.texture = ltex; tlight.texture_scale = 1.5; tlight.energy = 1.8; tlight.color = Color(0.65, 0.0, 1.0)
	_tornado_sprite.add_child(tlight)
	# Outer dark glow ring
	for ld: Array in [[18.0, Color(0.35, 0.0, 0.55, 0.12)], [7.0, Color(0.6, 0.0, 0.85, 0.35)], [2.0, Color(0.8, 0.0, 1.0, 0.75)]]:
		var ring := Line2D.new(); ring.closed = true; ring.antialiased = true
		ring.width = float(ld[0]); ring.default_color = ld[1]; ring.material = mat
		for i in 24:
			ring.add_point(Vector2.from_angle(float(i) / 24.0 * TAU) * 60.0)
		add_child(ring)
		var t := ring.create_tween().set_loops()
		t.tween_property(ring, "rotation", -TAU, PULL_TIME * 0.9) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
		get_tree().create_timer(EXPLODE_DELAY - 0.05).timeout.connect(func(): t.kill(); ring.queue_free())
	# Inward spiral arms (3 arms, dark energy)
	for i in 3:
		var arm := Line2D.new(); arm.material = mat; arm.width = 3.0
		arm.default_color = Color(0.5, 0.0, 0.72, 0.50)
		for j in 12:
			var a := float(j) / 11.0
			arm.add_point(Vector2.from_angle(float(i) / 3.0 * TAU + a * -TAU * 0.8) * lerpf(80.0, 8.0, a))
		add_child(arm)
		var t := arm.create_tween()
		t.tween_property(arm, "modulate:a", 0.0, EXPLODE_DELAY)
		t.tween_callback(arm.queue_free)

func _explode() -> void:
	_active = false
	var center := global_position
	_deal_aoe(center)
	# Tornado sprite quick fade — explosion sprite takes over
	if is_instance_valid(_tornado_sprite):
		var bt := _tornado_sprite.create_tween()
		bt.tween_property(_tornado_sprite, "modulate:a", 0.0, 0.12)
		bt.tween_callback(_tornado_sprite.queue_free)
	if _arena and _arena.has_method("screen_shake"):
		_arena.screen_shake(0.30, 10.0)
	# AoE explosion sprite — scales out from center
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var exp := Sprite2D.new()
	exp.texture = preload("res://effects/textures/dark_tornado_explosion.png")
	exp.material = mat
	exp.z_index = 6
	exp.scale = Vector2.ZERO
	add_child(exp); exp.global_position = center
	var t := exp.create_tween().set_parallel(true)
	t.tween_property(exp, "scale", Vector2.ONE * AOE_EXPLODE_SCALE, 0.42) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(exp, "modulate:a", 0.0, 0.42)
	t.set_parallel(false); t.tween_callback(exp.queue_free)
	_spawn_light(center, Color(0.65, 0.0, 1.0), 4.5, 4.0)
	var cleanup := create_tween()
	cleanup.tween_interval(0.55)
	cleanup.tween_callback(queue_free)

func _deal_aoe(center: Vector2) -> void:
	if not _arena or not _arena.has_method("get_all_alive_avatars"): return
	var my_team := int(_attacker.get("_team") if is_instance_valid(_attacker) else 1)
	for av in _arena.get_all_alive_avatars():
		if av.get("_team") != my_team and av.global_position.distance_to(center) <= AOE_RADIUS:
			if av.has_method("take_damage"):
				av.take_damage(_dmg, _kid)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.40); t.tween_callback(light.queue_free)
