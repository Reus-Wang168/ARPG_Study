class_name PlayerStateMachine
extends Node

var player
var states: Array[State] = []
var previous_state: State
var current_state: State


func Initialize(player_owner) -> void:
	player = player_owner
	states.clear()
	previous_state = null
	current_state = null

	for child in get_children():
		if child is State:
			var state := child as State
			state.Initialize(player, self)
			states.append(state)


func ChangeState(new_state: State) -> void:
	if new_state == null or new_state == current_state:
		return

	if current_state != null:
		previous_state = current_state
		current_state.Exit()

	current_state = new_state
	current_state.Enter()


func GetState(state_name: StringName) -> State:
	for state in states:
		if state.GetStateName() == state_name:
			return state

	return null


func PhysicsUpdate(delta: float) -> void:
	if current_state == null:
		if player != null:
			player.velocity = Vector2.ZERO
		return

	current_state.PhysicsUpdate(delta)


func GetCurrentStateName() -> StringName:
	if current_state == null:
		return &""

	return current_state.GetStateName()