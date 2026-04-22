class_name PlayerIdleState
extends State


func Enter() -> void:
	player.velocity = Vector2.ZERO


func PhysicsUpdate(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	if player.IsAttackRequested():
		TransitionTo(&"attack")
		return

	if player.direction != Vector2.ZERO:
		TransitionTo(&"walk")


func GetStateName() -> StringName:
	return &"idle"