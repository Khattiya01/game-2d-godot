extends Node2D
# T4a Team A — spinning yin-yang vortex, ×3.5 AoE 200 px

const DMG_FACTOR  := 3.5
const AOE_RADIUS  := 200.0
const SPIN_TIME    := 1.20   # vortex builds up then explodes
const VORTEX_SCALE := 0.175  # tune if sprite too big/small
const AURA_SCALE   := 0.20  # tune if aura too big/small
const RINGS_SCALE  := 0.28  # tune if charge rings too big/small

var _vortex_sprite: Sprite2D = null
var _aura_sprite:   Sprite2D = null

func fire(data: Dictionary) -> void:
	var attacker: Node = data.get("attacker")
	var target:   Node = data.get("target")
	var arena:    Node = data.get("arena")
	var dmult: float   = data.get("damage_mult", 1.0)
	var base: int      = int(data.get("base_dmg", 10))

	if not is_instance_valid(attacker):
		queue_free(); return

	var target_pos: Vector2 = target.global_position if is_instance_valid(target) else attacker.global_position
	global_position = attacker.global_position  # wind-up rings spin around caster
	var kid := str(attacker.get("player_id")) if is_instance_valid(attacker) else ""
	var dmg := maxi(1, int(float(base) * DMG_FACTOR * dmult))

	# Track attacker during wind-up so effect follows moving avatar
	var track_tw := create_tween()
	track_tw.tween_method(func(_t: float) -> void:
		if is_instance_valid(attacker):
			global_position = (attacker as Node2D).global_position
	, 0.0, 1.0, SPIN_TIME)

	_spawn_wind_up()

	var tw := create_tween()
	tw.tween_interval(SPIN_TIME)
	tw.tween_callback(func():
		_deal_aoe(attacker, arena, dmg, kid, target_pos)
		if arena and arena.has_method("screen_shake"):
			arena.screen_shake(0.30, 9.0)
		_burst_vortex_sprite(target_pos)
		_spawn_expand_rings(target_pos)
	)
	tw.tween_interval(0.55)
	tw.tween_callback(queue_free)

func _spawn_wind_up() -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Chi charge aura — slow counter-clockwise halo behind caster
	_aura_sprite = Sprite2D.new()
	_aura_sprite.texture = preload("res://effects/textures/chi_charge_aura.png")
	_aura_sprite.material = mat
	_aura_sprite.z_index = 3  # behind rings and center sprite
	_aura_sprite.scale = Vector2.ONE * AURA_SCALE
	add_child(_aura_sprite)
	# Counter-clockwise slow spin — TRANS_LINEAR, 1 turn per 1.8s
	var aura_spin := _aura_sprite.create_tween().set_loops()
	aura_spin.tween_property(_aura_sprite, "rotation", -TAU, 1.8).set_trans(Tween.TRANS_LINEAR)
	# PointLight2D wide cyan aura glow — per toolkit pattern
	var altex := GradientTexture2D.new()
	altex.fill = GradientTexture2D.FILL_RADIAL; altex.fill_from = Vector2(0.5, 0.5); altex.fill_to = Vector2(1.0, 0.5)
	var alg := Gradient.new(); alg.set_color(0, Color(1, 1, 1, 1)); alg.add_point(0.3, Color(0.3, 0.9, 1.0, 0.35)); alg.add_point(1.0, Color(0, 0, 0, 0))
	altex.gradient = alg; altex.width = 128; altex.height = 128
	var alight := PointLight2D.new()
	alight.texture = altex; alight.texture_scale = 3.5; alight.energy = 1.1; alight.color = Color(0.3, 0.9, 1.0)
	_aura_sprite.add_child(alight)

func _make_ring(width: float, col: Color, radius: float) -> Line2D:
	var ring := Line2D.new()
	ring.width = width; ring.default_color = col; ring.closed = true; ring.antialiased = true
	for i in 24:
		ring.add_point(Vector2.from_angle(float(i) / 24.0 * TAU) * radius)
	return ring

func _deal_aoe(attacker: Node, arena: Node, dmg: int, kid: String, center: Vector2) -> void:
	if not arena or not arena.has_method("get_all_alive_avatars"): return
	var my_team := int(attacker.get("_team") if is_instance_valid(attacker) else 1)
	for av in arena.get_all_alive_avatars():
		if av.get("_team") != my_team and av.global_position.distance_to(center) <= AOE_RADIUS:
			if av.has_method("take_damage"):
				av.take_damage(dmg, kid)

const AOE_EXPLODE_SCALE := 0.42  # tune if AoE explosion sprite too big/small

func _spawn_expand_rings(center: Vector2) -> void:
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# AoE explosion sprite — scales out from center to AOE_RADIUS
	var exp := Sprite2D.new()
	exp.texture = preload("res://effects/textures/taichi_aoe_explosion.png")
	exp.material = mat
	exp.z_index = 6
	exp.scale = Vector2.ZERO
	add_child(exp); exp.global_position = center
	var t := exp.create_tween().set_parallel(true)
	t.tween_property(exp, "scale", Vector2.ONE * AOE_EXPLODE_SCALE, 0.38) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(exp, "modulate:a", 0.0, 0.38)
	t.set_parallel(false); t.tween_callback(exp.queue_free)
	_spawn_light(center, Color(0.5, 1.0, 0.6), 4.0, 3.5)

func _burst_vortex_sprite(target_pos: Vector2) -> void:
	# Fade aura out on burst — chi released, halo dissipates
	if is_instance_valid(_aura_sprite):
		var at := _aura_sprite.create_tween().set_parallel(true)
		at.tween_property(_aura_sprite, "scale", Vector2.ONE * AURA_SCALE * 1.6, 0.22) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		at.tween_property(_aura_sprite, "modulate:a", 0.0, 0.22)
		at.set_parallel(false); at.tween_callback(_aura_sprite.queue_free)
	# Spawn vortex sprite at target position on burst — not during charge
	var mat := CanvasItemMaterial.new(); mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_vortex_sprite = Sprite2D.new()
	_vortex_sprite.texture = preload("res://effects/textures/taichi_vortex.png")
	_vortex_sprite.material = mat
	_vortex_sprite.z_index = 5
	_vortex_sprite.scale = Vector2.ONE * VORTEX_SCALE
	add_child(_vortex_sprite); _vortex_sprite.global_position = target_pos
	# Just appear at full scale and fade — no expand
	var bt := _vortex_sprite.create_tween()
	bt.tween_interval(0.20)
	bt.tween_property(_vortex_sprite, "modulate:a", 0.0, 0.50)
	bt.tween_callback(_vortex_sprite.queue_free)

func _spawn_light(pos: Vector2, col: Color, energy: float, sc: float) -> void:
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL; tex.fill_from = Vector2(0.5, 0.5); tex.fill_to = Vector2(1.0, 0.5)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.add_point(0.3, Color(col.r, col.g, col.b, 0.5)); g.add_point(1.0, Color(0, 0, 0, 0))
	tex.gradient = g; tex.width = 128; tex.height = 128
	var light := PointLight2D.new(); add_child(light)
	light.global_position = pos; light.texture = tex; light.texture_scale = sc; light.energy = energy; light.color = col
	var t := create_tween(); t.tween_property(light, "energy", 0.0, 0.40); t.tween_callback(light.queue_free)
