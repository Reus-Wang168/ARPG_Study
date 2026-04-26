class_name State
extends Node

var player
var state_machine: PlayerStateMachine


func Initialize(player_owner, player_state_machine: PlayerStateMachine) -> void:
	player = player_owner
	state_machine = player_state_machine


func Enter() -> void:
	pass


func Exit() -> void:
	pass


func PhysicsUpdate(_delta: float) -> void:
	pass


func GetStateName() -> StringName:
	return &""


func TransitionTo(state_name: StringName) -> void:
	if state_machine == null:
		return

	var next_state := state_machine.GetState(state_name)
	if next_state == null:
		return

	state_machine.ChangeState(next_state)