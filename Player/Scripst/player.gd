class_name Player
extends CharacterBody2D

var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed: float = 300.0

@onready var state_machine: PlayerStateMachine = $StateMachine

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $ExamplePlayerSprite
@onready var attack_effect_pivot: Node2D = get_node_or_null("AttackEffectPivot") as Node2D
@onready var attack_effect_sprite: Sprite2D = get_node_or_null("AttackEffectPivot/AttackEffectSprite") as Sprite2D
@onready var attack_audio_player: AudioStreamPlayer2D = get_node_or_null("Audio/AudioStreamPlayer2D") as AudioStreamPlayer2D


var jump_force: float = 600.0


# Called when the node enters the scene tree for the first time.
func _ready():
	if state_machine != null:
		state_machine.Initialize(self)
		ChangeState(&"idle")
	UpdateAnimation()


func _physics_process(delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")
	if direction != Vector2.ZERO and not IsAttacking():
		SetDirection(direction)

	if state_machine != null:
		state_machine.PhysicsUpdate(delta)
	else:
		velocity = Vector2.ZERO

	UpdateAnimation()
	move_and_slide()




func SetDirection(dir: Vector2) -> bool:
	if dir == Vector2.ZERO:
		return false

	if abs(dir.x) > abs(dir.y):
		cardinal_direction = Vector2.RIGHT if dir.x > 0.0 else Vector2.LEFT
	else:
		cardinal_direction = Vector2.DOWN if dir.y > 0.0 else Vector2.UP

	return true



func SetState(new_state: String) -> bool:
	return ChangeState(new_state)


func ChangeState(new_state: StringName) -> bool:
	if state_machine == null:
		return false

	var next_state := state_machine.GetState(new_state)
	if next_state == null:
		push_warning("Unknown player state: %s" % String(new_state))
		return false

	state_machine.ChangeState(next_state)
	return true


func GetStateName() -> String:
	if state_machine == null:
		return "idle"

	var state_name := state_machine.GetCurrentStateName()
	if state_name.is_empty():
		return "idle"

	return String(state_name)


func IsAttackRequested() -> bool:
	return Input.is_action_just_pressed("attack")


func IsAttacking() -> bool:
	if state_machine == null:
		return false

	return state_machine.GetCurrentStateName() == &"attack"


func PlayAttackSound() -> void:
	if attack_audio_player == null:
		return

	if attack_audio_player.is_playing():
		attack_audio_player.stop()

	attack_audio_player.play()


func GetMovementStateName() -> StringName:
	if direction != Vector2.ZERO:
		return &"walk"

	return &"idle"


func UpdateAnimation() -> void:
	if animation_player == null or sprite_2d == null:
		return

	var state_name := GetStateName()
	var anim_direction := AnimDirection()
	var animation_name := state_name + "_" + anim_direction

	if state_name == "attack":
		if attack_effect_pivot != null:
			attack_effect_pivot.scale = Vector2.ONE

		if attack_effect_sprite != null:
			attack_effect_sprite.flip_h = anim_direction == "left"
			attack_effect_sprite.flip_v = false

		if anim_direction == "left":
			animation_name = "attack_left"
		elif anim_direction == "right":
			animation_name = "attack_slide"
	elif attack_effect_sprite != null:
		attack_effect_sprite.visible = false

	if anim_direction == "left":
		if state_name != "attack":
			animation_name = state_name + "_right"
		sprite_2d.flip_h = true
	else:
		sprite_2d.flip_h = false

	if animation_player.current_animation != animation_name or not animation_player.is_playing():
		animation_player.play(animation_name)


func AnimDirection() -> String:
	if cardinal_direction == Vector2.UP:
		return "up"
	elif cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.LEFT:
		return "left"
	else:
		return "right"

