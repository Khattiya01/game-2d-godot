extends Node2D

const BUFF_DURATION: float = 8.0
const ATK_MULT: float = 1.20
const SFX := preload("res://assets/sounds/apply_buff_01.wav")

var _avatar: Node = null
var _done: bool = false

func fire(data: Dictionary) -> void:
	_avatar = data.get("avatar")
	if not is_instance_valid(_avatar):
		queue_free()
		return
	position = Vector2.ZERO
	var stacks: int = int(_avatar.get("_atk_buff_stacks")) + 1
	_avatar.set("_atk_buff_stacks", stacks)
	_avatar.set("_personal_atk_mult", ATK_MULT)
	_play_sound()
	_spawn_activation_burst()
	_spawn_aura()
	get_tree().create_timer(BUFF_DURATION).timeout.connect(_on_expire)

func _on_expire() -> void:
	if not is_instance_valid(self) or _done:
		return
	_done = true
	if is_instance_valid(_avatar):
		var stacks: int = maxi(0, int(_avatar.get("_atk_buff_stacks")) - 1)
		_avatar.set("_atk_buff_stacks", stacks)
		if stacks == 0:
			_avatar.set("_personal_atk_mult", 1.0)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.5)
	fade.tween_callback(func():
		if is_instance_valid(self):
			queue_free()
	)

func _play_sound() -> void:
	var player := AudioStreamPlayer2D.new()
	add_child(player)
	player.stream = SFX
	player.play()
	player.finished.connect(player.queue_free)

func _spawn_activation_burst() -> void:
	# Expanding white-cyan ring on activation
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	var ring_defs: Array = [
		[16.0, Color(0.5, 1.0, 1.0, 0.14)],
		[2.5,  Color(0.92, 1.0, 1.0, 0.92)],
	]
	for rd in ring_defs:
		var ring := Line2D.new()
		add_child(ring)
		ring.z_index = 5
		ring.material = mat
		ring.width = float(rd[0])
		ring.default_color = rd[1]
		ring.antialiased = true
		for j in 13:
			ring.add_point(Vector2.from_angle(TAU * float(j) / 12.0) * 22.0)
		var t := ring.create_tween().set_parallel(true)
		t.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.45) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(ring, "modulate:a", 0.0, 0.45)
		t.set_parallel(false)
		t.tween_callback(ring.queue_free)
	# "ATK UP" announce
	_spawn_buff_label(Color(0.7, 1.0, 1.0, 1.0), "ATK +20%")

func _spawn_aura() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Slowly rotating white-cyan chi ring
	var orbit := Line2D.new()
	add_child(orbit)
	orbit.z_index = 4
	orbit.material = mat
	orbit.width = 3.5
	orbit.default_color = Color(0.70, 1.0, 1.0, 0.65)
	orbit.antialiased = true
	for j in 25:
		orbit.add_point(Vector2.from_angle(TAU * float(j) / 24.0) * 28.0)
	var rot := create_tween().set_loops()
	rot.tween_property(orbit, "rotation", TAU, BUFF_DURATION) \
		.set_trans(Tween.TRANS_LINEAR)
	var pulse := create_tween().set_loops()
	pulse.tween_property(orbit, "modulate:a", 0.28, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse.tween_property(orbit, "modulate:a", 1.0, 1.2) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Ambient chi particles rising upward
	var grad := Gradient.new()
	grad.set_color(0, Color(0.75, 1.0, 1.0, 0.80))
	grad.set_color(1, Color(1.0, 1.0, 0.85, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 50.0
	pm.initial_velocity_min = 12.0
	pm.initial_velocity_max = 40.0
	pm.gravity = Vector3(0.0, -15.0, 0.0)
	pm.scale_min = 0.3
	pm.scale_max = 1.0
	pm.color_ramp = cramp
	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.z_index = 5
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 12
	particles.lifetime = 0.85
	particles.one_shot = false
	particles.emitting = true
	var pmat := CanvasItemMaterial.new()
	pmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	particles.material = pmat

func _spawn_buff_label(col: Color, text: String) -> void:
	var lbl := Label.new()
	add_child(lbl)
	lbl.text = text
	lbl.position = Vector2(-24, -36)
	lbl.size = Vector2(48, 14)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 2)
	var t := lbl.create_tween().set_parallel(true)
	t.tween_property(lbl, "position:y", lbl.position.y - 22.0, 0.85)
	t.tween_property(lbl, "modulate:a", 0.0, 0.85).set_delay(0.35)
	t.set_parallel(false)
	t.tween_callback(lbl.queue_free)

func _make_circle_tex() -> ImageTexture:
	const S := 8
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var c := Vector2(S * 0.5, S * 0.5)
	for y in S:
		for x in S:
			var a := clampf(1.0 - Vector2(x + 0.5, y + 0.5).distance_to(c) / (S * 0.5), 0.0, 1.0)
			img.set_pixel(x, y, Color(1.0, 1.0, 1.0, a))
	return ImageTexture.create_from_image(img)
