class_name HitBox
extends Area2D

@export var team: StringName = &"neutral"
@export var damage: int = 1
@export var box_size: Vector2 = Vector2(18.0, 14.0)
@export var box_offset: Vector2 = Vector2.ZERO
@export var starts_active: bool = false

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	ApplyShape()
	SetActive(starts_active)


func SetActive(enabled: bool) -> void:
	set_deferred("monitoring", enabled)
	set_deferred("monitorable", enabled)

	if collision_shape != null:
		collision_shape.set_deferred("disabled", not enabled)


func ApplyShape() -> void:
	if collision_shape == null:
		return

	var shape: RectangleShape2D = collision_shape.shape as RectangleShape2D
	if shape == null:
		shape = RectangleShape2D.new()

	shape.size = box_size
	collision_shape.shape = shape
	collision_shape.position = box_offset