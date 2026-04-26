class_name Player
extends CharacterBody2D

const HitBoxScript = preload("res://GeneralNodes/HitBox/hit_box.gd")
const HurtBoxScript = preload("res://GeneralNodes/HitBox/hurt_box.gd")

signal hit_received(hit_box: HitBoxScript)

var cardinal_direction: Vector2 = Vector2.DOWN
var direction: Vector2 = Vector2.ZERO
var move_speed: float = 300.0

@export var shadow_walk_scale_delta: Vector2 = Vector2(0.08, 0.08)
@export var shadow_walk_position_delta: Vector2 = Vector2(0.0, 1.2)
@export var shadow_walk_alpha_delta: float = 0.08
@export var shadow_walk_bob_speed: float = 9.0
@export var hurt_knockback_speed: float = 260.0
@export var hurt_knockback_friction: float = 1800.0
@export var hurt_invulnerability_duration: float = 0.45
@export var hurt_flash_interval: float = 0.06
@export var hurt_flash_color: Color = Color(1.6, 1.6, 1.6, 1.0)

@onready var state_machine: PlayerStateMachine = $StateMachine

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var sprite_2d: Sprite2D = $ExamplePlayerSprite
@onready var shadow_sprite: Sprite2D = get_node_or_null("ShadowSprite") as Sprite2D
@onready var hurt_box: HurtBoxScript = get_node_or_null("HurtBox") as HurtBoxScript
@onready var attack_effect_pivot: Node2D = get_node_or_null("AttackEffectPivot") as Node2D
@onready var attack_hit_box: HitBoxScript = get_node_or_null("AttackEffectPivot/AttackHitBox") as HitBoxScript
@onready var attack_effect_sprite: Sprite2D = get_node_or_null("AttackEffectPivot/AttackEffectSprite") as Sprite2D
@onready var attack_audio_player: AudioStreamPlayer2D = get_node_or_null("Audio/AudioStreamPlayer2D") as AudioStreamPlayer2D

var shadow_base_position: Vector2 = Vector2.ZERO
var shadow_base_scale: Vector2 = Vector2.ONE
var shadow_base_alpha: float = 1.0
var shadow_visual_time: float = 0.0
var hurt_knockback_velocity: Vector2 = Vector2.ZERO
var hurt_invulnerability_remaining: float = 0.0
var hurt_flash_elapsed: float = 0.0
var sprite_base_modulate: Color = Color.WHITE


var jump_force: float = 600.0


# Called when the node enters the scene tree for the first time.
func _ready():
	add_to_group("player")
	if sprite_2d != null:
		sprite_base_modulate = sprite_2d.modulate

	if shadow_sprite != null:
		shadow_base_position = shadow_sprite.position
		shadow_base_scale = shadow_sprite.scale
		shadow_base_alpha = shadow_sprite.modulate.a

	if hurt_box != null and not hurt_box.hit_received.is_connected(_on_hurt_box_hit_received):
		hurt_box.hit_received.connect(_on_hurt_box_hit_received)

	SetAttackHitBoxEnabled(false)

	if state_machine != null:
		state_machine.Initialize(self)
		ChangeState(&"idle")
	ApplyHurtVisuals()
	UpdateAnimation()
	UpdateShadow(0.0)


func _physics_process(delta: float) -> void:
	direction = Input.get_vector("left", "right", "up", "down")
	if direction != Vector2.ZERO and not IsAttacking():
		SetDirection(direction)

	if state_machine != null:
		state_machine.PhysicsUpdate(delta)
	else:
		velocity = Vector2.ZERO

	UpdateHurtState(delta)
	if hurt_knockback_velocity.length_squared() > 0.0001:
		velocity += hurt_knockback_velocity
		hurt_knockback_velocity = hurt_knockback_velocity.move_toward(Vector2.ZERO, hurt_knockback_friction * delta)
	else:
		hurt_knockback_velocity = Vector2.ZERO

	UpdateAnimation()
	UpdateShadow(delta)
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


func SetAttackHitBoxEnabled(enabled: bool) -> void:
	if attack_hit_box == null:
		return

	attack_hit_box.SetActive(enabled)


func _on_hurt_box_hit_received(hit_box: HitBoxScript) -> void:
	if hurt_invulnerability_remaining > 0.0:
		return

	StartHurtReaction(hit_box)
	hit_received.emit(hit_box)


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


func UpdateHurtState(delta: float) -> void:
	hurt_invulnerability_remaining = maxf(hurt_invulnerability_remaining - delta, 0.0)
	if hurt_invulnerability_remaining > 0.0:
		hurt_flash_elapsed += delta
		ApplyHurtVisuals()
		return

	if sprite_2d != null and sprite_2d.modulate != sprite_base_modulate:
		sprite_2d.modulate = sprite_base_modulate


func StartHurtReaction(hit_box: HitBoxScript) -> void:
	hurt_invulnerability_remaining = hurt_invulnerability_duration
	hurt_flash_elapsed = 0.0
	hurt_knockback_velocity = GetHurtKnockbackDirection(hit_box.global_position) * hurt_knockback_speed
	ApplyHurtVisuals()

	if IsAttacking():
		ChangeState(&"idle")


func GetHurtKnockbackDirection(from_global_position: Vector2) -> Vector2:
	var knockback_direction: Vector2 = global_position - from_global_position
	if knockback_direction.length_squared() <= 0.0001:
		knockback_direction = -cardinal_direction if cardinal_direction != Vector2.ZERO else Vector2.DOWN

	return knockback_direction.normalized()


func ApplyHurtVisuals() -> void:
	if sprite_2d == null:
		return

	if hurt_invulnerability_remaining <= 0.0:
		sprite_2d.modulate = sprite_base_modulate
		return

	var flash_step: int = int(floor(hurt_flash_elapsed / maxf(hurt_flash_interval, 0.01)))
	sprite_2d.modulate = hurt_flash_color if flash_step % 2 == 0 else sprite_base_modulate


func UpdateShadow(delta: float) -> void:
	if shadow_sprite == null:
		return

	shadow_visual_time += delta

	var target_position: Vector2 = shadow_base_position
	var target_scale: Vector2 = shadow_base_scale
	var target_alpha: float = shadow_base_alpha
	var state_name: String = GetStateName()

	if state_name == "walk" and direction != Vector2.ZERO:
		var bob: float = (sin(shadow_visual_time * shadow_walk_bob_speed) + 1.0) * 0.5
		target_position += shadow_walk_position_delta * bob
		target_scale += shadow_walk_scale_delta * bob
		target_alpha = clampf(shadow_base_alpha + shadow_walk_alpha_delta * bob, 0.0, 1.0)
	elif state_name == "attack":
		target_scale += shadow_walk_scale_delta * 0.25
		target_alpha = clampf(shadow_base_alpha + shadow_walk_alpha_delta * 0.2, 0.0, 1.0)

	var blend: float = clampf(delta * 14.0, 0.0, 1.0)
	shadow_sprite.position = shadow_sprite.position.lerp(target_position, blend)
	shadow_sprite.scale = shadow_sprite.scale.lerp(target_scale, blend)

	var shadow_modulate: Color = shadow_sprite.modulate
	shadow_modulate.a = lerpf(shadow_modulate.a, target_alpha, blend)
	shadow_sprite.modulate = shadow_modulate


func AnimDirection() -> String:
	if cardinal_direction == Vector2.UP:
		return "up"
	elif cardinal_direction == Vector2.DOWN:
		return "down"
	elif cardinal_direction == Vector2.LEFT:
		return "left"
	else:
		return "right"
