class_name SlimeEnemy
extends CharacterBody2D

const HitBoxScript = preload("res://GeneralNodes/HitBox/hit_box.gd")
const HurtBoxScript = preload("res://GeneralNodes/HitBox/hurt_box.gd")

@export var max_health: int = 3
@export var hop_speed: float = 180.0
@export var hop_duration: float = 0.2
@export var hop_cooldown: float = 0.65
@export var chase_range: float = 220.0
@export var attack_range: float = 28.0
@export var attack_pattern_range: float = 96.0
@export var attack_axis_hop_count: int = 3
@export var hop_stop_distance: float = 20.0
@export var home_return_tolerance: float = 8.0
@export var separation_radius: float = 34.0
@export var separation_weight: float = 1.15
@export var contact_damage: int = 1
@export var hit_stun_duration: float = 0.14
@export var hit_knockback_speed: float = 210.0
@export var hit_knockback_friction: float = 1200.0
@export var hit_flash_duration: float = 0.08
@export var hit_flash_color: Color = Color(1.35, 0.8, 0.8, 1.0)
@export var idle_animation_name: StringName = &"idle"
@export var hop_animation_name: StringName = &"hop"
@export var death_animation_name: StringName = &"death"

@onready var sprite_2d: Sprite2D = get_node_or_null("Sprite2D") as Sprite2D
@onready var shadow_sprite_2d: Sprite2D = get_node_or_null("ShadowSprite2D") as Sprite2D
@onready var destroy_smoke_sprite_2d: Sprite2D = get_node_or_null("DestroySmokeSprite2D") as Sprite2D
@onready var hurt_box: HurtBoxScript = get_node_or_null("HurtBox") as HurtBoxScript
@onready var attack_hit_box: HitBoxScript = get_node_or_null("AttackHitBox") as HitBoxScript
@onready var collision_shape_2d: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer") as AnimationPlayer

var current_health: int = 0
var hop_cooldown_remaining: float = 0.0
var hop_time_remaining: float = 0.0
var hop_direction: Vector2 = Vector2.ZERO
var target: Node2D
var active_animation_name: StringName = StringName()
var knockback_velocity: Vector2 = Vector2.ZERO
var hit_stun_remaining: float = 0.0
var hit_flash_remaining: float = 0.0
var sprite_base_modulate: Color = Color.WHITE
var home_position: Vector2 = Vector2.ZERO
var attack_is_active: bool = false
var attack_pattern_active: bool = false
var attack_axis_is_horizontal: bool = true
var attack_hops_on_current_axis: int = 0
var attack_direction_sign: int = 1
var is_dying: bool = false


func _ready() -> void:
	current_health = max_health
	home_position = global_position
	add_to_group("enemies")
	if sprite_2d != null:
		sprite_base_modulate = sprite_2d.modulate

	if hurt_box != null and not hurt_box.hit_received.is_connected(_on_hurt_box_hit_received):
		hurt_box.hit_received.connect(_on_hurt_box_hit_received)

	if attack_hit_box != null:
		attack_hit_box.team = &"enemy"
		attack_hit_box.damage = contact_damage
		attack_hit_box.SetActive(false)

	if destroy_smoke_sprite_2d != null:
		destroy_smoke_sprite_2d.visible = false

	if animation_player != null and not animation_player.animation_finished.is_connected(_on_animation_player_animation_finished):
		animation_player.animation_finished.connect(_on_animation_player_animation_finished)

	ResolveTarget()
	PlayAnimation(idle_animation_name)


func _physics_process(delta: float) -> void:
	if is_dying:
		velocity = Vector2.ZERO
		return

	if target == null or not is_instance_valid(target):
		ResolveTarget()

	hop_cooldown_remaining = maxf(hop_cooldown_remaining - delta, 0.0)
	hit_stun_remaining = maxf(hit_stun_remaining - delta, 0.0)
	UpdateHitFlash(delta)

	var movement_velocity: Vector2 = Vector2.ZERO
	var used_hop_movement: bool = false

	if hit_stun_remaining > 0.0:
		SetAttackActive(false)
	else:
		if hop_time_remaining > 0.0:
			hop_time_remaining = maxf(hop_time_remaining - delta, 0.0)
			movement_velocity = hop_direction * hop_speed
			used_hop_movement = true
			PlayAnimation(hop_animation_name, false, GetHopAnimationSpeed())
			if hop_time_remaining <= 0.0:
				SetAttackActive(false)
		else:
			movement_velocity = velocity.move_toward(Vector2.ZERO, hop_speed * 5.0 * delta)
			PlayAnimation(idle_animation_name)
			TryStartHop()

	if knockback_velocity.length_squared() > 0.0001:
		movement_velocity += knockback_velocity
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, hit_knockback_friction * delta)
	else:
		knockback_velocity = Vector2.ZERO

	velocity = movement_velocity
	UpdateContactDamageState()

	UpdateVisuals()
	move_and_slide()
	if used_hop_movement:
		HandleHopCollision()


func ResolveTarget() -> void:
	var players_in_group: Array[Node] = get_tree().get_nodes_in_group("player")
	for player_node in players_in_group:
		if player_node is Node2D:
			target = player_node as Node2D
			return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		target = null
		return

	target = scene_root.find_child("Player", true, false) as Node2D


func TryStartHop() -> void:
	if hop_cooldown_remaining > 0.0:
		return

	var goal_position: Vector2 = GetGoalPosition()
	if goal_position == Vector2.INF:
		ResetAttackPattern()
		return

	var goal_stop_distance: float = GetGoalStopDistance(goal_position)
	var to_target: Vector2 = goal_position - global_position
	var distance_to_target: float = to_target.length()
	if ShouldUseAttackPattern(goal_position, distance_to_target):
		StartAttackPatternHop(to_target)
		return

	ResetAttackPattern()
	if distance_to_target <= goal_stop_distance:
		return

	var travel_distance: float = distance_to_target - goal_stop_distance
	if travel_distance <= 0.0:
		return

	hop_direction = GetAxisAlignedDirection(
		GetSeparatedDirection(to_target.normalized(), goal_position != home_position)
	)
	hop_time_remaining = minf(hop_duration, travel_distance / hop_speed)
	if hop_time_remaining <= 0.0:
		return
	hop_cooldown_remaining = hop_cooldown
	PlayAnimation(hop_animation_name, true, GetHopAnimationSpeed())
	UpdateContactDamageState()


func ShouldUseAttackPattern(goal_position: Vector2, distance_to_target: float) -> bool:
	if goal_position == home_position:
		return false

	return distance_to_target <= attack_pattern_range


func StartAttackPatternHop(to_target: Vector2) -> void:
	if hop_duration <= 0.0:
		return

	if not attack_pattern_active:
		attack_pattern_active = true
		attack_axis_is_horizontal = true
		attack_hops_on_current_axis = 0
		attack_direction_sign = GetAxisDirectionSign(to_target.x, 1)
	elif attack_hops_on_current_axis >= attack_axis_hop_count:
		attack_axis_is_horizontal = not attack_axis_is_horizontal
		attack_hops_on_current_axis = 0
		attack_direction_sign = GetAxisDirectionSign(GetAttackAxisDelta(to_target), attack_direction_sign)

	hop_direction = GetAttackPatternDirection()
	hop_time_remaining = hop_duration
	hop_cooldown_remaining = hop_cooldown
	attack_hops_on_current_axis += 1
	PlayAnimation(hop_animation_name, true, GetHopAnimationSpeed())
	UpdateContactDamageState()


func ResetAttackPattern() -> void:
	attack_pattern_active = false
	attack_axis_is_horizontal = true
	attack_hops_on_current_axis = 0
	attack_direction_sign = 1


func GetAttackPatternDirection() -> Vector2:
	if attack_axis_is_horizontal:
		return Vector2(float(attack_direction_sign), 0.0)

	return Vector2(0.0, float(attack_direction_sign))


func GetAttackAxisDelta(direction: Vector2) -> float:
	if attack_axis_is_horizontal:
		return direction.x

	return direction.y


func GetAxisAlignedDirection(direction: Vector2) -> Vector2:
	if direction.length_squared() <= 0.0001:
		return Vector2.ZERO

	if absf(direction.x) >= absf(direction.y):
		return Vector2.RIGHT if direction.x >= 0.0 else Vector2.LEFT

	return Vector2.DOWN if direction.y >= 0.0 else Vector2.UP


func GetAxisDirectionSign(axis_delta: float, fallback: int = 1) -> int:
	if axis_delta > 0.001:
		return 1
	if axis_delta < -0.001:
		return -1

	return fallback if fallback != 0 else 1


func HandleHopCollision() -> void:
	for collision_index in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		if collision == null:
			continue
		if collision.get_normal().dot(hop_direction) >= -0.35:
			continue

		hop_time_remaining = 0.0
		if attack_pattern_active:
			attack_direction_sign = -GetAxisDirectionSign(GetAttackAxisDelta(hop_direction), attack_direction_sign)
		break


func SetAttackActive(active: bool) -> void:
	if attack_hit_box == null or attack_is_active == active:
		return

	attack_is_active = active
	attack_hit_box.damage = contact_damage
	attack_hit_box.SetActive(active)


func UpdateContactDamageState() -> void:
	if attack_hit_box == null:
		return

	if hit_stun_remaining > 0.0 or target == null or not is_instance_valid(target):
		SetAttackActive(false)
		return

	var distance_to_target: float = global_position.distance_to(target.global_position)
	SetAttackActive(distance_to_target <= attack_range + hop_stop_distance)


func UpdateVisuals() -> void:
	if sprite_2d == null:
		return

	if absf(velocity.x) > 0.01:
		sprite_2d.flip_h = velocity.x < 0.0


func PlayAnimation(animation_name: StringName, restart: bool = false, custom_speed: float = 1.0) -> void:
	if animation_player == null:
		return

	if animation_name == StringName():
		return

	if not restart and active_animation_name == animation_name and animation_player.is_playing():
		return

	active_animation_name = animation_name
	animation_player.play(String(animation_name), -1.0, custom_speed)


func GetHopAnimationSpeed() -> float:
	if animation_player == null:
		return 1.0

	if not animation_player.has_animation(String(hop_animation_name)):
		return 1.0

	var hop_animation: Animation = animation_player.get_animation(String(hop_animation_name))
	if hop_animation == null or hop_animation.length <= 0.0 or hop_duration <= 0.0:
		return 1.0

	return hop_animation.length / hop_duration


func GetGoalPosition() -> Vector2:
	if target != null and is_instance_valid(target):
		var distance_to_target: float = global_position.distance_to(target.global_position)
		if distance_to_target <= chase_range:
			return target.global_position

	if global_position.distance_to(home_position) > home_return_tolerance:
		return home_position

	return Vector2.INF


func GetGoalStopDistance(goal_position: Vector2) -> float:
	if goal_position == home_position:
		return home_return_tolerance

	return hop_stop_distance


func GetSeparatedDirection(base_direction: Vector2, use_separation: bool) -> Vector2:
	if not use_separation:
		return base_direction

	var separation: Vector2 = Vector2.ZERO
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		if enemy_node == self:
			continue

		var other_enemy: Node2D = enemy_node as Node2D
		if other_enemy == null:
			continue

		var away_from_other: Vector2 = global_position - other_enemy.global_position
		var distance_to_other: float = away_from_other.length()
		if distance_to_other <= 0.001 or distance_to_other > separation_radius:
			continue

		separation += away_from_other.normalized() * (1.0 - (distance_to_other / separation_radius))

	var combined_direction: Vector2 = base_direction + separation * separation_weight
	if combined_direction.length_squared() <= 0.0001:
		return base_direction

	return combined_direction.normalized()


func UpdateHitFlash(delta: float) -> void:
	if sprite_2d == null:
		return

	hit_flash_remaining = maxf(hit_flash_remaining - delta, 0.0)
	if hit_flash_remaining > 0.0:
		sprite_2d.modulate = hit_flash_color
		return

	if sprite_2d.modulate != sprite_base_modulate:
		sprite_2d.modulate = sprite_base_modulate


func ApplyHitReaction(from_global_position: Vector2) -> void:
	var knockback_direction: Vector2 = global_position - from_global_position
	if knockback_direction.length_squared() <= 0.0001:
		knockback_direction = -hop_direction if hop_direction != Vector2.ZERO else Vector2.DOWN

	hop_time_remaining = 0.0
	hit_stun_remaining = hit_stun_duration
	hit_flash_remaining = hit_flash_duration
	knockback_velocity = knockback_direction.normalized() * hit_knockback_speed
	SetAttackActive(false)

	if sprite_2d != null:
		sprite_2d.modulate = hit_flash_color


func StartDeathSequence() -> void:
	if is_dying:
		return

	is_dying = true
	hop_time_remaining = 0.0
	hop_cooldown_remaining = 0.0
	hit_stun_remaining = 0.0
	hit_flash_remaining = 0.0
	knockback_velocity = Vector2.ZERO
	velocity = Vector2.ZERO
	ResetAttackPattern()
	SetAttackActive(false)

	if collision_shape_2d != null:
		collision_shape_2d.set_deferred("disabled", true)

	if hurt_box != null:
		hurt_box.set_deferred("monitoring", false)
		hurt_box.set_deferred("monitorable", false)
		if hurt_box.collision_shape != null:
			hurt_box.collision_shape.set_deferred("disabled", true)

	if destroy_smoke_sprite_2d != null:
		destroy_smoke_sprite_2d.frame = 0
		destroy_smoke_sprite_2d.visible = true

	if sprite_2d != null:
		sprite_2d.modulate = sprite_base_modulate

	if animation_player != null and animation_player.has_animation(String(death_animation_name)):
		PlayAnimation(death_animation_name, true, 1.0)
		return

	queue_free()


func _on_hurt_box_hit_received(hit_box: HitBoxScript) -> void:
	if is_dying:
		return

	current_health -= hit_box.damage
	if current_health <= 0:
		StartDeathSequence()
		return

	ApplyHitReaction(hit_box.global_position)
	if animation_player != null and animation_player.has_animation(String(hop_animation_name)):
		animation_player.play(String(hop_animation_name), -1.0, GetHopAnimationSpeed() * 1.1, true)
		active_animation_name = hop_animation_name


func _on_animation_player_animation_finished(animation_name: StringName) -> void:
	if not is_dying or animation_name != death_animation_name:
		return

	queue_free()