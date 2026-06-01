extends Node2D

const DAMAGE_INITIAL: int = 60   # first strike — all chained targets
const DAMAGE_TICK: int = 40      # second zap at midpoint (~0.85s)
const CHAIN_COUNT: int = 3
const HOLD_DURATION: float = 1.7
const FADE_DURATION: float = 0.3
const ZIGZAG_SEGMENTS: int = 8
const FLICKER_INTERVAL: float = 1.0 / 12.0  # redraw 12x/sec for lightning stutter
const TICK_TIME: float = HOLD_DURATION * 0.5  # midpoint second zap

var _on_complete: Callable = Callable()
var _attacker: Node = null
var _targets: Array = []
var _active: bool = false
var _elapsed: float = 0.0
var _flicker_timer: float = 0.0
var _ticked: bool = false
var _damage_mult: float = 1.0

@onready var sfx: AudioStreamPlayer2D = $SFX

func fire(effect_data: Dictionary) -> void:
	_attacker = effect_data.get("attacker", null)
	var primary: Node = effect_data.get("target", null)
	var team: int = effect_data.get("team", 1)
	var arena: Node = effect_data.get("arena", null)
	_on_complete = effect_data.get("on_complete", Callable())
	_damage_mult = effect_data.get("damage_mult", 1.0)

	sfx.play()
	if not primary or not is_instance_valid(primary):
		_finish()
		return

	# Build chain: primary + up to 2 nearest enemies
	_targets = [primary]
	if arena and arena.has_method("get_nearest_on_team_excluding"):
		for _i in range(CHAIN_COUNT - 1):
			var last_pos: Vector2 = _targets[-1].global_position
			var next: Node = arena.get_nearest_on_team_excluding(last_pos, 3 - team, _targets)
			if next and is_instance_valid(next):
				_targets.append(next)

	# First strike — all chained targets
	for t in _targets:
		if is_instance_valid(t) and t.has_method("take_damage"):
			t.take_damage(int(float(DAMAGE_INITIAL) * _damage_mult))

	_active = true
	_elapsed = 0.0
	_flicker_timer = 0.0
	_ticked = false
	_redraw_bolts()

func _process(delta: float) -> void:
	if not _active:
		return
	_elapsed += delta
	_flicker_timer -= delta
	if _flicker_timer <= 0.0:
		_flicker_timer = FLICKER_INTERVAL
		_redraw_bolts()
	# Second zap at midpoint
	if not _ticked and _elapsed >= TICK_TIME:
		_ticked = true
		for t in _targets:
			if is_instance_valid(t) and t.has_method("take_damage"):
				t.take_damage(int(float(DAMAGE_TICK) * _damage_mult))

	if _elapsed >= HOLD_DURATION:
		_active = false
		var tween := create_tween()
		tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
		tween.tween_callback(_finish)

func _redraw_bolts() -> void:
	# Free previous bolt geometry (skip non-Line2D children like SFX)
	for child in get_children():
		if child is Line2D:
			child.free()

	# Rebuild from current (live) positions so bolts track moving avatars
	if not _attacker or not is_instance_valid(_attacker):
		_active = false
		_finish()
		return
	var points: Array[Vector2] = [_attacker.global_position]
	for t in _targets:
		if is_instance_valid(t):
			points.append(t.global_position)
		else:
			break

	for i in range(points.size() - 1):
		_add_bolt(points[i], points[i + 1])

func _add_bolt(start: Vector2, end_pos: Vector2) -> void:
	var dist: float = start.distance_to(end_pos)
	var perp: Vector2 = (end_pos - start).orthogonal().normalized()
	var max_disp: float = clampf(dist * 0.18, 10.0, 42.0)

	# Zigzag with sin-envelope so displacement tapers at both endpoints
	var pts: Array[Vector2] = [start]
	for i in range(1, ZIGZAG_SEGMENTS):
		var t: float = float(i) / float(ZIGZAG_SEGMENTS)
		var base: Vector2 = start.lerp(end_pos, t)
		pts.append(base + perp * randf_range(-max_disp, max_disp) * sin(t * PI))
	pts.append(end_pos)

	# 3-layer bolt: deep indigo aura → electric violet glow → ice-blue core
	_make_line(pts, 16.0, Color(0.15, 0.05, 0.85, 0.13))
	_make_line(pts, 6.5,  Color(0.45, 0.25, 1.00, 0.55))
	_make_line(pts, 1.8,  Color(0.72, 0.88, 1.00, 1.00))

	# Short crackle branches off random mid-points
	_add_branches(pts, dist)

func _add_branches(pts: Array[Vector2], main_dist: float) -> void:
	for _b in range(2):
		var idx: int = randi_range(1, pts.size() - 2)
		var root: Vector2 = pts[idx]
		var length: float = minf(main_dist * randf_range(0.05, 0.10), 40.0)
		var angle: float = randf_range(0.0, TAU)
		var tip: Vector2 = root + Vector2(cos(angle), sin(angle)) * length
		var mid: Vector2 = root.lerp(tip, 0.5) + Vector2(
			randf_range(-length * 0.2, length * 0.2),
			randf_range(-length * 0.2, length * 0.2)
		)
		var bpts: Array[Vector2] = [root, mid, tip]
		_make_line(bpts, 3.0, Color(0.35, 0.15, 0.90, 0.35))
		_make_line(bpts, 1.2, Color(0.65, 0.80, 1.00, 0.80))

func _make_line(pts: Array[Vector2], width: float, color: Color) -> void:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(line)
	for p in pts:
		line.add_point(p)

func _finish() -> void:
	if _on_complete.is_valid():
		_on_complete.call()
	queue_free()
