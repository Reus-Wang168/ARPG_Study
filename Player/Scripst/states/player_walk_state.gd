class_name PlayerWalkState
extends State


func Enter() -> void:
	player.velocity = player.direction * player.move_speed


func PhysicsUpdate(_delta: float) -> void:
	if player.IsAttackRequested():
		TransitionTo(&"attack")
		return

	if player.direction == Vector2.ZERO:
		TransitionTo(&"idle")
		return

	player.velocity = player.direction * player.move_speed


func GetStateName() -> StringName:
	return &"walk"
