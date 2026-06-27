extends CharacterBody2D

const SPEED := 240.0
const SYNC_INTERVAL := 0.05
const GLOW_DURATION := 0.35
const GLOW_COLOR := Color(1.0, 0.95, 0.35)
const NORMAL_COLOR := Color.WHITE
const DEFAULT_CHARACTER_ID := "player_a"
const CHARACTER_ORDER := ["player_a", "player_e", "rei"]
const CHARACTER_TEXTURES := {
	"player_a": preload("res://assets/characters/player_a.png"),
	"player_e": preload("res://assets/characters/player_e.png"),
	"rei": preload("res://assets/characters/sprite_rei.png"),
}
const FRAME_FRONT := 0
const FRAME_BACK := 1
const FRAME_LEFT := 2
const FRAME_RIGHT := 3
const FRAME_SIZE := 16

var player_id := 0
var is_local_player := false
var character_id := DEFAULT_CHARACTER_ID
var facing_frame := FRAME_FRONT
var sync_timer := 0.0
var glow_timer := 0.0
var space_was_pressed := false
var key_1_was_pressed := false
var key_2_was_pressed := false
var key_3_was_pressed := false
var tab_was_pressed := false

@onready var sprite: Sprite2D = $Sprite
@onready var name_label: Label = $NameLabel


func setup(new_player_id: int, new_is_local_player: bool, new_character_id: String = DEFAULT_CHARACTER_ID) -> void:
	player_id = new_player_id
	is_local_player = new_is_local_player
	character_id = _normalize_character_id(new_character_id)
	set_multiplayer_authority(player_id)

	if is_node_ready():
		_apply_character_visual()
		_apply_glow_visual()
		_update_label()


func _ready() -> void:
	_apply_character_visual()
	_apply_glow_visual()
	_update_label()


func _apply_glow_visual() -> void:
	if glow_timer > 0.0:
		sprite.modulate = GLOW_COLOR
		sprite.scale = Vector2(1.25, 1.25)
		return

	sprite.modulate = NORMAL_COLOR
	sprite.scale = Vector2.ONE


func _apply_character_visual() -> void:
	if not is_instance_valid(sprite):
		return

	var texture: Texture2D = CHARACTER_TEXTURES[character_id] as Texture2D
	var frame_count: int = maxi(1, int(texture.get_width() / FRAME_SIZE))
	sprite.texture = texture
	sprite.hframes = frame_count
	sprite.vframes = 1
	_apply_facing_frame()


func _apply_facing_frame() -> void:
	if not is_instance_valid(sprite):
		return

	if character_id == "rei":
		sprite.frame = 0
		return

	sprite.frame = min(facing_frame, sprite.hframes - 1)


func _physics_process(delta: float) -> void:
	_tick_glow(delta)

	if not is_local_player:
		return

	_handle_character_switch_input()
	_handle_glow_input()

	var direction: Vector2 = Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1

	if direction != Vector2.ZERO:
		_set_facing_from_direction(direction)

	velocity = direction.normalized() * SPEED
	move_and_slide()

	sync_timer += delta
	if sync_timer >= SYNC_INTERVAL:
		sync_timer = 0.0
		sync_position.rpc(global_position, facing_frame)


func _handle_character_switch_input() -> void:
	var key_1_pressed: bool = Input.is_key_pressed(KEY_1)
	var key_2_pressed: bool = Input.is_key_pressed(KEY_2)
	var key_3_pressed: bool = Input.is_key_pressed(KEY_3)
	var tab_pressed: bool = Input.is_key_pressed(KEY_TAB)

	if key_1_pressed and not key_1_was_pressed:
		_request_character_change("player_a")
	if key_2_pressed and not key_2_was_pressed:
		_request_character_change("player_e")
	if key_3_pressed and not key_3_was_pressed:
		_request_character_change("rei")
	if tab_pressed and not tab_was_pressed:
		_request_next_character()

	key_1_was_pressed = key_1_pressed
	key_2_was_pressed = key_2_pressed
	key_3_was_pressed = key_3_pressed
	tab_was_pressed = tab_pressed


func _handle_glow_input() -> void:
	var is_space_pressed: bool = Input.is_key_pressed(KEY_SPACE)
	if is_space_pressed and not space_was_pressed:
		trigger_glow.rpc()
		_start_glow()
	space_was_pressed = is_space_pressed


func _request_next_character() -> void:
	var current_index: int = CHARACTER_ORDER.find(character_id)
	if current_index == -1:
		_request_character_change(DEFAULT_CHARACTER_ID)
		return

	var next_index: int = (current_index + 1) % CHARACTER_ORDER.size()
	_request_character_change(String(CHARACTER_ORDER[next_index]))


func _request_character_change(new_character_id: String) -> void:
	var normalized_id: String = _normalize_character_id(new_character_id)
	if normalized_id == character_id:
		return

	apply_character(normalized_id)
	sync_character.rpc(normalized_id)


func _set_facing_from_direction(direction: Vector2) -> void:
	var new_frame: int = facing_frame
	if absf(direction.x) > absf(direction.y):
		if direction.x < 0.0:
			new_frame = FRAME_LEFT
		else:
			new_frame = FRAME_RIGHT
	elif direction.y < 0.0:
		new_frame = FRAME_BACK
	else:
		new_frame = FRAME_FRONT

	if new_frame == facing_frame:
		return

	facing_frame = new_frame
	_apply_facing_frame()


func _tick_glow(delta: float) -> void:
	if glow_timer <= 0.0:
		return

	glow_timer -= delta
	if glow_timer <= 0.0:
		glow_timer = 0.0
		_apply_glow_visual()


func _start_glow() -> void:
	glow_timer = GLOW_DURATION
	_apply_glow_visual()


func get_character_id() -> String:
	return character_id


func apply_character(new_character_id: String) -> void:
	character_id = _normalize_character_id(new_character_id)
	_apply_character_visual()
	_update_label()


func _normalize_character_id(new_character_id: String) -> String:
	if CHARACTER_TEXTURES.has(new_character_id):
		return new_character_id
	return DEFAULT_CHARACTER_ID


func _update_label() -> void:
	if not is_instance_valid(name_label):
		return

	if is_local_player:
		name_label.text = "Player %s (voce) - %s" % [player_id, character_id]
	else:
		name_label.text = "Player %s - %s" % [player_id, character_id]


@rpc("any_peer", "call_remote", "unreliable")
func sync_position(remote_position: Vector2, remote_facing_frame: int = FRAME_FRONT) -> void:
	if is_local_player:
		return

	global_position = remote_position
	facing_frame = remote_facing_frame
	_apply_facing_frame()


@rpc("any_peer", "call_remote", "reliable")
func trigger_glow() -> void:
	_start_glow()


@rpc("any_peer", "call_remote", "reliable")
func sync_character(new_character_id: String) -> void:
	apply_character(new_character_id)
