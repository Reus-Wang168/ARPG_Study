class_name PlayerAttackState
extends State


func Enter() -> void:
	player.velocity = Vector2.ZERO
	if player != null:
		player.SetAttackHitBoxEnabled(true)
		player.PlayAttackSound()


func Exit() -> void:
	if player != null:
		player.SetAttackHitBoxEnabled(false)


func PhysicsUpdate(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	if player.animation_player == null:
		TransitionTo(player.GetMovementStateName())
		return

	if player.animation_player.current_animation.begins_with("attack_") and player.animation_player.is_playing():
		return

	TransitionTo(player.GetMovementStateName())


func GetStateName() -> StringName:
	return &"attack"