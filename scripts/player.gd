extends CharacterBody2D

const SPEED := 240.0
const SYNC_INTERVAL := 0.05
const GLOW_DURATION := 0.35
const LOCAL_COLOR := Color(0.25, 0.82, 0.45)
const REMOTE_COLOR := Color(0.25, 0.52, 0.95)
const GLOW_COLOR := Color(1.0, 0.95, 0.35)

var player_id := 0
var is_local_player := false
var sync_timer := 0.0
var glow_timer := 0.0
var space_was_pressed := false

@onready var visual: Polygon2D = $Visual
@onready var name_label: Label = $NameLabel


func setup(new_player_id: int, new_is_local_player: bool) -> void:
	player_id = new_player_id
	is_local_player = new_is_local_player
	set_multiplayer_authority(player_id)

	if is_node_ready():
		_apply_visual_state()


func _ready() -> void:
	_apply_visual_state()


func _apply_visual_state() -> void:
	if glow_timer > 0.0:
		visual.color = GLOW_COLOR
		visual.scale = Vector2(1.25, 1.25)
		_update_label()
		return

	if is_local_player:
		visual.color = LOCAL_COLOR
	else:
		visual.color = REMOTE_COLOR
	visual.scale = Vector2.ONE

	_update_label()


func _physics_process(delta: float) -> void:
	_tick_glow(delta)

	if not is_local_player:
		return

	var is_space_pressed := Input.is_key_pressed(KEY_SPACE)
	if is_space_pressed and not space_was_pressed:
		trigger_glow.rpc()
		_start_glow()
	space_was_pressed = is_space_pressed

	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1

	velocity = direction.normalized() * SPEED
	move_and_slide()

	sync_timer += delta
	if sync_timer >= SYNC_INTERVAL:
		sync_timer = 0.0
		sync_position.rpc(global_position)


func _tick_glow(delta: float) -> void:
	if glow_timer <= 0.0:
		return

	glow_timer -= delta
	if glow_timer <= 0.0:
		glow_timer = 0.0
		_apply_visual_state()


func _start_glow() -> void:
	glow_timer = GLOW_DURATION
	_apply_visual_state()


func _update_label() -> void:
	if not is_instance_valid(name_label):
		return

	if is_local_player:
		name_label.text = "Player %s (voce)" % player_id
	else:
		name_label.text = "Player %s" % player_id


@rpc("any_peer", "call_remote", "unreliable")
func sync_position(remote_position: Vector2) -> void:
	if is_local_player:
		return

	global_position = remote_position


@rpc("any_peer", "call_remote", "reliable")
func trigger_glow() -> void:
	_start_glow()
