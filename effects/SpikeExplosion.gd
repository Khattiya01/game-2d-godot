extends Node2D

const SPIKE_COUNT: int = 10
const MAX_HITS: int = 4
const DMG_FACTOR: float = 0.55   # AoE penalty: 4 targets × 0.55 ≈ 2.2× base (cf. Lightning ~2.0×)
const FLY_TIME: float = 0.32
const FAN_DEGREES: float = 28.0
const RANGE: float = 540.0
const SPIKE_TIP: float = 28.0
const SPIKE_BASE: float = 4.0
const RING_SEGS: int = 32

const C_WHITE    := Color(1.00, 1.00, 1.00, 1.00)
const C_DIMWHITE := Color(0.68, 0.68, 0.68, 1.00)
const C_RING     := Color(0.06, 0.06, 0.06, 0.95)

@onready var burst_particles: GPUParticles2D = $BurstParticles
@onready var launch_sound: AudioStreamPlayer2D = $LaunchSound

var _arena: Node = null
var _target_team: int = 2
var _base_dmg: int = 10
var _dmg_mult: float = 1.0
var _on_complete: Callable
var _hit_count: int = 0

func fire(effect_data: Dictionary) -> void:
	var from_pos: Vector2 = effect_data.get("from_pos", Vector2.ZERO)
	_arena       = effect_data.get("arena", null)
	_target_team = effect_data.get("target_team", 2)
	_base_dmg    = int(effect_data.get("base_dmg", 10))
	_dmg_mult    = effect_data.get("damage_mult", 1.0)
	_on_complete = effect_data.get("on_complete", Callable())
	position     = from_pos

	launch_sound.play()
	burst_particles.emitting = true

	# Additive material for white-hot spikes and flash
	var add_mat := CanvasItemMaterial.new()
	add_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD

	_spawn_white_flash(add_mat)
	_spawn_shockwave_ring()

	# Gather nearest enemies
	var enemy_targets: Array = []
	if _arena:
		for _i in MAX_HITS:
			var nxt = _arena.get_nearest_on_team_excluding(
				global_position, _target_team, enemy_targets)
			if nxt and is_instance_valid(nxt):
				enemy_targets.append(nxt)

	var base_dir := Vector2.RIGHT if _target_team == 2 else Vector2.LEFT

	for i in SPIKE_COUNT:
		var spike := _make_spike(i, add_mat)
		add_child(spike)

		var local_target: Vector2
		if i < enemy_targets.size():
			local_target = enemy_targets[i].global_position - global_position
		else:
			var fan := deg_to_rad(randf_range(-FAN_DEGREES, FAN_DEGREES))
			local_target = base_dir.rotated(fan) * RANGE

		spike.rotation = local_target.angle()
		var target_enemy: Node = enemy_targets[i] if i < enemy_targets.size() else null

		var t := create_tween()
		t.tween_property(spike, "position", local_target, FLY_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_callback(_on_spike_hit.bind(spike, target_enemy))

	await get_tree().create_timer(FLY_TIME + 0.15).timeout
	if _on_complete.is_valid():
		_on_complete.call()
	await get_tree().create_timer(burst_particles.lifetime + 0.1).timeout
	queue_free()

func _on_spike_hit(spike: Node2D, target: Node) -> void:
	if target and is_instance_valid(target) and _hit_count < MAX_HITS:
		_hit_count += 1
		var dmg := maxi(1, int(float(_base_dmg) * DMG_FACTOR * _dmg_mult))
		if target.has_method("take_damage"):
			target.take_damage(dmg)
	if is_instance_valid(spike):
		var fade := create_tween()
		fade.tween_property(spike, "modulate:a", 0.0, 0.10)

# Sharp needle-like shard — alternates bright white / dim white
func _make_spike(index: int, mat: CanvasItemMaterial) -> Polygon2D:
	var s := Polygon2D.new()
	s.color = C_WHITE if index % 2 == 0 else C_DIMWHITE
	s.material = mat
	s.polygon = PackedVector2Array([
		Vector2(SPIKE_TIP,  0.0),
		Vector2(-4.0,  SPIKE_BASE),
		Vector2(-4.0, -SPIKE_BASE),
	])
	return s

# Brief white-hot burst at origin
func _spawn_white_flash(mat: CanvasItemMaterial) -> void:
	var flash := Polygon2D.new()
	flash.material = mat
	flash.color = C_WHITE
	var pts: PackedVector2Array = []
	for i in 16:
		var a := (float(i) / 16.0) * TAU
		pts.append(Vector2(cos(a), sin(a)) * 22.0)
	flash.polygon = pts
	add_child(flash)

	var t := flash.create_tween()
	t.set_parallel(true)
	t.tween_property(flash, "scale", Vector2.ONE * 3.8, 0.06) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(flash, "modulate:a", 0.0, 0.06)
	t.set_parallel(false)
	t.tween_callback(flash.queue_free)

# Dark expanding ring — gives a void / shockwave feel
func _spawn_shockwave_ring() -> void:
	var ring_node := Node2D.new()
	ring_node.scale = Vector2.ZERO
	add_child(ring_node)

	var ring_line := Line2D.new()
	ring_line.default_color = C_RING
	ring_line.width = 5.5
	ring_line.antialiased = true
	var pts: PackedVector2Array = []
	for i in RING_SEGS + 1:
		var a := (float(i) / RING_SEGS) * TAU
		pts.append(Vector2(cos(a), sin(a)) * 55.0)
	ring_line.points = pts
	ring_node.add_child(ring_line)

	var t := ring_node.create_tween()
	t.tween_property(ring_node, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	t.tween_property(ring_line, "modulate:a", 0.0, 0.24)
	t.tween_callback(ring_node.queue_free)
