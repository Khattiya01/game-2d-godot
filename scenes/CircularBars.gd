extends Node2D

# Circular arc bars wrapping the avatar.
# Right half = HP (clockwise from top), Left half = EXP (counter-clockwise from top).

const RADIUS := 18.0
const WIDTH := 3.0
const SEGS := 48

const HP_BG := Color(0.08, 0.08, 0.08, 0.85)
const EXP_BG := Color(0.05, 0.05, 0.05, 0.75)
const EXP_COLOR := Color(1.0, 0.78, 0.0, 0.9)

var hp_ratio: float = 1.0
var exp_ratio: float = 0.0
var _hp_override: Color = Color.TRANSPARENT

func _draw() -> void:
	var hp_col: Color
	if _hp_override.a > 0.01:
		hp_col = _hp_override
	else:
		hp_col = Color(
			lerpf(0.15, 0.9, 1.0 - hp_ratio),
			lerpf(0.15, 0.88, hp_ratio),
			0.15, 1.0
		)

	# Right half: HP background (-90° → +90° clockwise through right)
	draw_arc(Vector2.ZERO, RADIUS, -PI * 0.5, PI * 0.5, SEGS, HP_BG, WIDTH, true)
	# Right half: HP fill from top downward clockwise
	if hp_ratio > 0.001:
		draw_arc(Vector2.ZERO, RADIUS, -PI * 0.5, -PI * 0.5 + PI * hp_ratio, SEGS, hp_col, WIDTH, true)

	# Left half: EXP background (+90° → +270° clockwise through left)
	draw_arc(Vector2.ZERO, RADIUS, PI * 0.5, PI * 1.5, SEGS, EXP_BG, WIDTH, true)
	# Left half: EXP fill from top downward counter-clockwise (fills upward from 270°)
	if exp_ratio > 0.001:
		draw_arc(Vector2.ZERO, RADIUS, PI * 1.5 - PI * exp_ratio, PI * 1.5, SEGS, EXP_COLOR, WIDTH, true)

func set_hp(ratio: float) -> void:
	hp_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func set_exp(ratio: float) -> void:
	exp_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func flash_hp_green() -> void:
	_hp_override = Color(0.0, 1.0, 0.35, 1.0)
	queue_redraw()
	var t := create_tween()
	t.tween_interval(0.35)
	t.tween_callback(func() -> void:
		_hp_override = Color.TRANSPARENT
		queue_redraw()
	)
