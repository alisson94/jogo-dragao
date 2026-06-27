extends Node2D

const PORT := 8910
const MAX_CLIENTS := 1
const PLAYER_SCENE := preload("res://scenes/player.tscn")

@onready var players_root: Node2D = $Players

var players: Dictionary = {}
var local_player_id := 0
var network_peer: ENetMultiplayerPeer

var ip_input: LineEdit
var host_button: Button
var join_button: Button
var alert_button: Button
var status_label: Label
var alert_label: Label


func _ready() -> void:
	_build_ui()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_set_status("Sem conexao")


func _build_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "UI"
	add_child(canvas)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 220)
	panel.offset_left = 12
	panel.offset_top = 12
	panel.offset_right = 482
	panel.offset_bottom = 232
	canvas.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 8)
	panel.add_child(layout)

	var connection_row := HBoxContainer.new()
	connection_row.add_theme_constant_override("separation", 8)
	layout.add_child(connection_row)

	host_button = Button.new()
	host_button.text = "Hospedar"
	host_button.focus_mode = Control.FOCUS_NONE
	host_button.pressed.connect(_on_host_pressed)
	connection_row.add_child(host_button)

	ip_input = LineEdit.new()
	ip_input.text = "127.0.0.1"
	ip_input.placeholder_text = "IP Hamachi do host"
	ip_input.custom_minimum_size = Vector2(170, 0)
	connection_row.add_child(ip_input)

	join_button = Button.new()
	join_button.text = "Entrar"
	join_button.focus_mode = Control.FOCUS_NONE
	join_button.pressed.connect(_on_join_pressed)
	connection_row.add_child(join_button)

	alert_button = Button.new()
	alert_button.text = "Enviar aviso"
	alert_button.disabled = true
	alert_button.focus_mode = Control.FOCUS_NONE
	alert_button.pressed.connect(_on_alert_pressed)
	layout.add_child(alert_button)

	var help_label := Label.new()
	help_label.text = "Porta UDP %s | Hamachi: entre usando o IP Hamachi de quem hospedou | Espaco: brilhar" % PORT
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(help_label)

	status_label = Label.new()
	status_label.text = ""
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(status_label)

	alert_label = Label.new()
	alert_label.text = "Avisos recebidos aparecem aqui"
	alert_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(alert_label)


func _on_host_pressed() -> void:
	_reset_session()

	network_peer = ENetMultiplayerPeer.new()
	var error := network_peer.create_server(PORT, MAX_CLIENTS)
	if error != OK:
		_set_status("Nao foi possivel hospedar. Erro: %s" % error)
		return

	multiplayer.multiplayer_peer = network_peer
	local_player_id = multiplayer.get_unique_id()
	_spawn_player(local_player_id, _spawn_position_for(local_player_id))
	_set_connected_ui(true)
	_set_status("Hospedando em UDP %s. Envie seu IP Hamachi para o outro jogador." % PORT)


func _on_join_pressed() -> void:
	_reset_session()

	var address := ip_input.text.strip_edges()
	if address.is_empty():
		address = "127.0.0.1"
		ip_input.text = address

	network_peer = ENetMultiplayerPeer.new()
	var error := network_peer.create_client(address, PORT)
	if error != OK:
		_set_status("Nao foi possivel entrar. Erro: %s" % error)
		return

	multiplayer.multiplayer_peer = network_peer
	_set_status("Conectando em %s:%s via UDP..." % [address, PORT])


func _on_alert_pressed() -> void:
	if not multiplayer.has_multiplayer_peer():
		_set_status("Conecte antes de enviar aviso.")
		return

	var sender_id := _get_local_player_id()
	receive_alert.rpc(sender_id)
	alert_label.text = "Aviso enviado como Player %s" % sender_id


func _on_peer_connected(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	if players.size() >= MAX_CLIENTS + 1:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		_set_status("Sessao cheia. Um terceiro jogador foi recusado.")
		return

	var spawn_position := _spawn_position_for(peer_id)
	_spawn_player(peer_id, spawn_position)

	for player_id in players:
		spawn_player_remote.rpc_id(peer_id, player_id, players[player_id].global_position)

	for connected_peer_id in multiplayer.get_peers():
		if connected_peer_id != peer_id:
			spawn_player_remote.rpc_id(connected_peer_id, peer_id, spawn_position)

	_set_status("Jogador conectado: Player %s" % peer_id)


func _on_peer_disconnected(peer_id: int) -> void:
	_remove_player(peer_id)
	if multiplayer.is_server():
		remove_player_remote.rpc(peer_id)
		_set_status("Player %s saiu. Aguardando outro jogador." % peer_id)
	else:
		_set_status("Player %s saiu." % peer_id)


func _on_connected_to_server() -> void:
	local_player_id = multiplayer.get_unique_id()
	_set_connected_ui(true)
	_set_status("Conectado como Player %s" % local_player_id)


func _on_connection_failed() -> void:
	_reset_session()
	_set_status("Falha ao conectar.")


func _on_server_disconnected() -> void:
	_reset_session()
	_set_status("Servidor desconectado.")


func _reset_session() -> void:
	for player in players.values():
		player.queue_free()
	players.clear()
	local_player_id = 0
	multiplayer.multiplayer_peer = null
	network_peer = null
	_set_connected_ui(false)
	alert_label.text = "Avisos recebidos aparecem aqui"


func _set_connected_ui(is_connected: bool) -> void:
	host_button.disabled = is_connected
	join_button.disabled = is_connected
	ip_input.editable = not is_connected
	alert_button.disabled = not is_connected


func _set_status(message: String) -> void:
	status_label.text = "Status: %s" % message


func _spawn_player(player_id: int, spawn_position: Vector2) -> void:
	if players.has(player_id):
		players[player_id].global_position = spawn_position
		return

	var player = PLAYER_SCENE.instantiate()
	player.name = "Player_%s" % player_id
	players_root.add_child(player)
	player.setup(player_id, player_id == _get_local_player_id())
	player.global_position = spawn_position
	players[player_id] = player


func _remove_player(player_id: int) -> void:
	if not players.has(player_id):
		return

	players[player_id].queue_free()
	players.erase(player_id)


func _spawn_position_for(player_id: int) -> Vector2:
	if player_id == 1:
		return Vector2(260, 280)
	return Vector2(460, 280)


func _get_local_player_id() -> int:
	if local_player_id != 0:
		return local_player_id
	if multiplayer.has_multiplayer_peer():
		return multiplayer.get_unique_id()
	return 0


@rpc("authority", "call_remote", "reliable")
func spawn_player_remote(player_id: int, spawn_position: Vector2) -> void:
	_spawn_player(player_id, spawn_position)


@rpc("authority", "call_remote", "reliable")
func remove_player_remote(player_id: int) -> void:
	_remove_player(player_id)


@rpc("any_peer", "call_remote", "reliable")
func receive_alert(sender_id: int) -> void:
	alert_label.text = "Aviso recebido do Player %s" % sender_id
