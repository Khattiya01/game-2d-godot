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
var ult_ratio: float = 0.0
var ult_team: int = 1
var _hp_override: Color = Color.TRANSPARENT
var _ult_flash: bool = false

const ULT_BAR_W := 40.0
const ULT_BAR_H := 4.0
const ULT_BAR_Y := RADIUS + 7.0   # just below arc bottom

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

	# Private ultimate meter bar (horizontal, centered below arc)
	var bar_x := -ULT_BAR_W * 0.5
	draw_rect(Rect2(bar_x, ULT_BAR_Y, ULT_BAR_W, ULT_BAR_H), Color(0.08, 0.08, 0.08, 0.85))
	if ult_ratio > 0.001:
		var fill_col: Color
		if _ult_flash:
			fill_col = Color(1.0, 1.0, 1.0, 1.0)
		elif ult_team == 1:
			fill_col = Color(0.15, 0.88, 1.0, 0.95).lerp(Color(0.8, 1.0, 1.0, 1.0), ult_ratio)
		else:
			fill_col = Color(0.65, 0.0, 0.9, 0.95).lerp(Color(1.0, 0.2, 0.45, 1.0), ult_ratio)
		draw_rect(Rect2(bar_x, ULT_BAR_Y, ULT_BAR_W * ult_ratio, ULT_BAR_H), fill_col)
	# Bar border
	draw_rect(Rect2(bar_x - 0.5, ULT_BAR_Y - 0.5, ULT_BAR_W + 1.0, ULT_BAR_H + 1.0),
		Color(0.0, 0.0, 0.0, 0.55), false)

func set_hp(ratio: float) -> void:
	hp_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func set_exp(ratio: float) -> void:
	exp_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func set_team(team: int) -> void:
	ult_team = team

func set_ult(ratio: float) -> void:
	ult_ratio = clampf(ratio, 0.0, 1.0)
	queue_redraw()

func flash_ult_full() -> void:
	_ult_flash = true
	queue_redraw()
	var t := create_tween()
	t.tween_interval(0.35)
	t.tween_callback(func() -> void:
		_ult_flash = false
		ult_ratio = 0.0
		queue_redraw()
	)

func flash_hp_green() -> void:
	_hp_override = Color(0.0, 1.0, 0.35, 1.0)
	queue_redraw()
	var t := create_tween()
	t.tween_interval(0.35)
	t.tween_callback(func() -> void:
		_hp_override = Color.TRANSPARENT
		queue_redraw()
	)
