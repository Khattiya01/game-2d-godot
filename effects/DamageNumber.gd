extends Node2D

func show_number(amount: int) -> void:
	$Label.text = "-%d" % amount
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 35.0, 0.9)
	tween.tween_property(self, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
