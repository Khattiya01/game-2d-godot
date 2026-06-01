extends Node2D

const DAMAGE_PER_TICK: int = 20
const TICK_INTERVAL: float = 0.5
const BEAM_DURATION: float = 3.0

var _attacker: Node = null
var _target: Node = null
var _elapsed: float = 0.0
var _tick_timer: float = 0.0
var _active: bool = false
var _finishing: bool = false
var _on_complete: Callable = Callable()
var _damage_mult: float = 1.0

var _beam_outer: Line2D
var _beam_inner: Line2D

@onready var sfx: AudioStreamPlayer2D = $SFX

func _ready() -> void:
	_beam_outer = Line2D.new()
	_beam_outer.width = 8.0
	_beam_outer.default_color = Color(0.3, 0.9, 1.0, 0.3)
	add_child(_beam_outer)

	_beam_inner = Line2D.new()
	_beam_inner.width = 2.5
	_beam_inner.default_color = Color(0.85, 0.98, 1.0, 1.0)
	add_child(_beam_inner)

func fire(effect_data: Dictionary) -> void:
	_attacker = effect_data.get("attacker", null)
	_target = effect_data.get("target", null)
	_on_complete = effect_data.get("on_complete", Callable())
	_damage_mult = effect_data.get("damage_mult", 1.0)
	# Anchor to attacker if provided, else fall back to from_pos
	if _attacker and is_instance_valid(_attacker):
		global_position = _attacker.global_position
	else:
		global_position = effect_data.get("from_pos", Vector2.ZERO)
	_active = true
	_elapsed = 0.0
	_tick_timer = 0.0
	sfx.play()

func _process(delta: float) -> void:
	if not _active:
		return

	_elapsed += delta
	_tick_timer += delta

	if not _target or not is_instance_valid(_target):
		_finish()
		return

	# Track attacker movement every frame so beam origin follows the shooter
	if _attacker and is_instance_valid(_attacker):
		global_position = _attacker.global_position

	var end_local: Vector2 = _target.global_position - global_position
	_beam_outer.clear_points()
	_beam_outer.add_point(Vector2.ZERO)
	_beam_outer.add_point(end_local)
	_beam_inner.clear_points()
	_beam_inner.add_point(Vector2.ZERO)
	_beam_inner.add_point(end_local)

	if _tick_timer >= TICK_INTERVAL:
		_tick_timer -= TICK_INTERVAL
		if _target and is_instance_valid(_target) and _target.has_method("take_damage"):
			_target.take_damage(int(float(DAMAGE_PER_TICK) * _damage_mult))

	if _elapsed >= BEAM_DURATION:
		_finish()

func _finish() -> void:
	if _finishing:
		return
	_finishing = true
	_active = false
	_beam_outer.clear_points()
	_beam_inner.clear_points()
	if _on_complete.is_valid():
		_on_complete.call()
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(queue_free)
