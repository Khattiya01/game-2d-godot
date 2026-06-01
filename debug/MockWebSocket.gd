extends Node

## Keyboard-driven stand-in for WebSocketManager.
## Emits the exact same signals so GameManager works identically
## whether use_mock is true or false.
##
## Key map:
##   1  →  chat  "1"  (join Team A)
##   2  →  chat  "2"  (join Team B)
##   Q  →  gift  rose      from Team A
##   W  →  gift  universe  from Team B
##   E  →  gift  rose      from Team B   (extra: B fires rose)
##   L  →  like  ×10

signal chat_received(username: String, message: String, avatar_url: String)
signal gift_received(username: String, gift_name: String, avatar_url: String, from_team: int)
signal like_received(username: String, count: int)

const _KEY_MAP := {
	KEY_1: {"type": "chat",  "msg": "1",         "team": 0},
	KEY_2: {"type": "chat",  "msg": "2",         "team": 0},
	KEY_Q: {"type": "gift",  "msg": "rose",      "team": 1},
	KEY_W: {"type": "gift",  "msg": "universe",  "team": 2},
	KEY_E: {"type": "gift",  "msg": "rose",      "team": 2},
	KEY_L: {"type": "like",  "msg": "",          "team": 0},
}

var _counter: int = 0

func _ready() -> void:
	print("[MockWebSocket] Active — keyboard controls:")
	print("  1=TeamA  2=TeamB  Q=RoseA  W=UnivB  E=RoseB  L=Like×10")

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var entry: Dictionary = _KEY_MAP.get(event.keycode, {})
	if entry.is_empty():
		return
	get_viewport().set_input_as_handled()
	_counter += 1
	var user := "TestUser_%02d" % _counter
	match entry["type"]:
		"chat":
			_log("KEY_%s → chat  %-14s  team=%s" % [
				event.keycode, '"%s"' % user, entry["msg"]
			])
			emit_signal("chat_received", user, entry["msg"], "")
		"gift":
			var t: int = entry["team"]
			_log("KEY_%s → gift  %-14s  %s  from=Team%s" % [
				event.keycode, '"%s"' % user, entry["msg"], "A" if t == 1 else "B"
			])
			emit_signal("gift_received", user, entry["msg"], "", t)
		"like":
			_log("KEY_L → like  %-14s  count=10" % ('"%s"' % user))
			emit_signal("like_received", user, 10)

func _log(msg: String) -> void:
	print("[MockWebSocket] %s" % msg)
