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
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# 8 blood-red spark lines radiating outward
	for i in 8:
		var angle := TAU * float(i) / 8.0 + randf_range(-0.15, 0.15)
		var line := Line2D.new()
		add_child(line)
		line.z_index = 5
		line.material = mat
		line.width = 3.5
		line.default_color = Color(1.0, 0.20, 0.05, 0.92)
		line.antialiased = true
		line.add_point(Vector2.ZERO)
		line.add_point(Vector2.from_angle(angle) * randf_range(18.0, 30.0))
		var t := line.create_tween().set_parallel(true)
		t.tween_property(line, "scale", Vector2(1.8, 1.8), 0.30) \
			.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		t.tween_property(line, "modulate:a", 0.0, 0.30)
		t.set_parallel(false)
		t.tween_callback(line.queue_free)
	_spawn_buff_label(Color(1.0, 0.28, 0.08, 1.0), "RAGE +20%")

func _spawn_aura() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	# Pulsing blood-red rage ring (no rotation — throbs in place)
	var rage_ring := Line2D.new()
	add_child(rage_ring)
	rage_ring.z_index = 4
	rage_ring.material = mat
	rage_ring.width = 3.5
	rage_ring.default_color = Color(0.95, 0.10, 0.0, 0.55)
	rage_ring.antialiased = true
	for j in 25:
		rage_ring.add_point(Vector2.from_angle(TAU * float(j) / 24.0) * 26.0)
	var pulse_a := create_tween().set_loops()
	pulse_a.tween_property(rage_ring, "modulate:a", 0.12, 0.50) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_a.tween_property(rage_ring, "modulate:a", 1.0, 0.50) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var pulse_s := create_tween().set_loops()
	pulse_s.tween_property(rage_ring, "scale", Vector2(1.14, 1.14), 0.50) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	pulse_s.tween_property(rage_ring, "scale", Vector2.ONE, 0.50) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Rising fire particles from below avatar
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.40, 0.05, 0.90))
	grad.set_color(1, Color(0.70, 0.08, 0.0, 0.00))
	var cramp := GradientTexture1D.new()
	cramp.gradient = grad
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
	pm.direction = Vector3(0.0, -1.0, 0.0)
	pm.spread = 32.0
	pm.initial_velocity_min = 22.0
	pm.initial_velocity_max = 62.0
	pm.gravity = Vector3(0.0, -22.0, 0.0)
	pm.scale_min = 0.4
	pm.scale_max = 1.2
	pm.color_ramp = cramp
	var particles := GPUParticles2D.new()
	add_child(particles)
	particles.z_index = 5
	particles.position = Vector2(0.0, 8.0)
	particles.texture = _make_circle_tex()
	particles.process_material = pm
	particles.amount = 14
	particles.lifetime = 0.60
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
	lbl.size = Vector2(52, 14)
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
