extends Node2D

const DURATION: float = 50.0
const FADE_TIME: float = 0.5
const PULSE_SCALE_MAX: float = 1.05
const BASE_RADIUS: float = 22.0
const RADIUS_STEP: float = 11.0
const CIRCLE_SEGMENTS: int = 32
const SHIELD_HP: int = 60     # damage points this layer absorbs before breaking

var _shield_hp: int = SHIELD_HP
var _broken: bool = false

@onready var circle_line: Line2D = $CircleLine
@onready var glow_line: Line2D = $GlowLine
@onready var flash_polygon: Polygon2D = $FlashPolygon
@onready var shield_sound: AudioStreamPlayer2D = $ShieldSound

func _ready() -> void:
	add_to_group("shield_bubble")

func fire(effect_data: Dictionary) -> void:
	var stack_index: int = effect_data.get("stack_index", 0)
	var radius := BASE_RADIUS + float(stack_index) * RADIUS_STEP
	_shield_hp = SHIELD_HP
	_broken = false
	position = Vector2.ZERO
	modulate.a = 1.0

	# Deeper rings = brighter blue; outer rings = lighter and more transparent
	var t_c := clampf(float(stack_index) / 4.0, 0.0, 1.0)
	var core_color := Color(
		lerpf(0.25, 0.78, t_c), lerpf(0.72, 0.96, t_c), 1.0, lerpf(0.95, 0.50, t_c)
	)
	var glow_color := Color(
		core_color.r * 0.45, core_color.g * 0.55, 1.0, lerpf(0.28, 0.10, t_c)
	)
	circle_line.default_color = core_color
	glow_line.default_color   = glow_color

	var pts: PackedVector2Array = []
	for i in CIRCLE_SEGMENTS + 1:
		var angle := (float(i) / CIRCLE_SEGMENTS) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * radius)
	circle_line.points = pts
	glow_line.points   = pts

	var flash_pts: PackedVector2Array = []
	for i in 24:
		var angle := (float(i) / 24.0) * TAU
		flash_pts.append(Vector2(cos(angle), sin(angle)) * (radius * 0.9))
	flash_polygon.polygon = flash_pts
	flash_polygon.modulate.a = 0.4
	create_tween().tween_property(flash_polygon, "modulate:a", 0.0, 0.3)

	shield_sound.play()

	var on_complete: Callable = effect_data.get("on_complete", Callable())
	if on_complete.is_valid():
		on_complete.call()

	# Pulse 1.0 ↔ 1.05
	var pt := create_tween().set_loops()
	pt.tween_property(self, "scale", Vector2.ONE * PULSE_SCALE_MAX, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pt.tween_property(self, "scale", Vector2.ONE, 0.5) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# Time-based expiry via signal lambda — avoids coroutine-drop bug
	get_tree().create_timer(DURATION - FADE_TIME).timeout.connect(func():
		if not is_instance_valid(self) or _broken:
			return
		pt.kill()
		var fade := create_tween()
		fade.tween_property(self, "modulate:a", 0.0, FADE_TIME)
		fade.tween_callback(func():
			if is_instance_valid(self):
				queue_free()
		)
	)

# Called by PlayerAvatar.take_damage() — absorbs damage, returns leftover
func absorb_damage(incoming: int, _killer_id: String = "") -> int:
	if _broken or _shield_hp <= 0:
		return incoming
	var absorbed := mini(incoming, _shield_hp)
	_shield_hp -= absorbed
	var remaining := incoming - absorbed
	if _shield_hp <= 0:
		_break_shield()
	else:
		# Hit flash: briefly enlarge then return
		var flash := create_tween()
		flash.tween_property(self, "scale", Vector2.ONE * 1.18, 0.04)
		flash.tween_property(self, "scale", Vector2.ONE, 0.14)
	return remaining

func _break_shield() -> void:
	if _broken:
		return
	_broken = true
	circle_line.default_color = Color(1.0, 1.0, 1.0, 0.9)
	glow_line.default_color   = Color(0.7, 0.85, 1.0, 0.5)
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.5, 0.08)
	tween.tween_property(self, "modulate:a", 0.0, 0.18)
	tween.tween_callback(func():
		if is_instance_valid(self):
			queue_free()
	)
