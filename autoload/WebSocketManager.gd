extends Node

## Real WebSocket client — connects to the Node.js tiktok-live-connector bridge.
## Emits the same signals as MockWebSocket so GameManager is connector-agnostic.
##
## Expected JSON from Node.js server:
##   {"type":"chat",  "username":"u","comment":"1","avatar":"https://..."}
##   {"type":"gift",  "username":"u","giftName":"Rose","team":1,"avatar":"..."}
##   {"type":"like",  "username":"u","likeCount":5}
##   {"type":"ping"}   (keepalive, no action needed)

signal chat_received(username: String, message: String, avatar_url: String)
signal gift_received(username: String, gift_name: String, avatar_url: String, from_team: int)
signal like_received(username: String, count: int)

@export var server_url: String = "ws://localhost:8765"
@export var reconnect_delay: float = 3.0

var _socket := WebSocketPeer.new()
var _state: int = WebSocketPeer.STATE_CLOSED
var _reconnecting: bool = false

func _ready() -> void:
	_connect()

func _process(_delta: float) -> void:
	_socket.poll()
	var new_state := _socket.get_ready_state()

	if new_state != _state:
		_on_state_changed(new_state)
		_state = new_state

	if _state == WebSocketPeer.STATE_OPEN:
		while _socket.get_available_packet_count() > 0:
			_handle_packet(_socket.get_packet())

func _connect() -> void:
	_reconnecting = false
	var err := _socket.connect_to_url(server_url)
	if err != OK:
		push_error("[WSManager] connect_to_url failed (err=%d) — retry in %.1fs" % [err, reconnect_delay])
		_schedule_reconnect()
		return
	_log("Connecting → %s" % server_url)

func _on_state_changed(new_state: int) -> void:
	match new_state:
		WebSocketPeer.STATE_OPEN:
			_log("Connected ✓")
		WebSocketPeer.STATE_CLOSING:
			_log("Closing…")
		WebSocketPeer.STATE_CLOSED:
			var code := _socket.get_close_code()
			var reason := _socket.get_close_reason()
			_log("Closed  code=%d  reason='%s'" % [code, reason])
			if not _reconnecting:
				_schedule_reconnect()

func _schedule_reconnect() -> void:
	if _reconnecting:
		return
	_reconnecting = true
	_log("Reconnecting in %.1fs…" % reconnect_delay)
	get_tree().create_timer(reconnect_delay).timeout.connect(_connect, CONNECT_ONE_SHOT)

func _handle_packet(data: PackedByteArray) -> void:
	var text := data.get_string_from_utf8()
	var payload = JSON.parse_string(text)
	if payload == null or not payload is Dictionary:
		push_warning("[WSManager] Unparseable packet: %s" % text.left(120))
		return

	match payload.get("type", ""):
		"chat":
			var comment: String = str(payload.get("comment", "")).strip_edges()
			if comment in ["1", "2"]:
				var user: String  = payload.get("username", "unknown")
				var avatar: String = payload.get("avatar",   "")
				_log("chat  %-18s  → \"%s\"" % [user, comment])
				emit_signal("chat_received", user, comment, avatar)

		"gift":
			var user: String    = payload.get("username", "unknown")
			var gift: String    = str(payload.get("giftName", "")).to_lower()
			var avatar: String  = payload.get("avatar", "")
			var team: int       = _to_int(payload.get("team", 0))
			if gift in ["rose", "universe"] and team in [1, 2]:
				_log("gift  %-18s  %s  team=%d" % [user, gift, team])
				emit_signal("gift_received", user, gift, avatar, team)

		"like":
			var user: String  = payload.get("username", "unknown")
			var cnt: int      = _to_int(payload.get("likeCount", 1))
			_log("like  %-18s  ×%d" % [user, cnt])
			emit_signal("like_received", user, cnt)

		"ping":
			pass  # keepalive, ignore

		var unknown:
			if not str(unknown).is_empty():
				push_warning("[WSManager] Unknown event type: %s" % unknown)

func _to_int(v) -> int:
	if v is int:   return v
	if v is float: return int(v)
	return int(str(v))

func _log(msg: String) -> void:
	print("[WSManager] %s" % msg)
