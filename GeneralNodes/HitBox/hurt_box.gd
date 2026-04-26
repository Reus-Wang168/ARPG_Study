class_name HurtBox
extends Area2D

const HitBoxScript = preload("res://GeneralNodes/HitBox/hit_box.gd")

signal hit_received(hit_box: HitBoxScript)

@export var team: StringName = &"neutral"
@export var shape_radius: float = 10.0
@export var shape_offset: Vector2 = Vector2.ZERO

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	ApplyShape()
	monitoring = true
	monitorable = false
	area_entered.connect(_on_area_entered)


func ApplyShape() -> void:
	if collision_shape == null:
		return

	var shape: CircleShape2D = collision_shape.shape as CircleShape2D
	if shape == null:
		shape = CircleShape2D.new()

	shape.radius = shape_radius
	collision_shape.shape = shape
	collision_shape.position = shape_offset


func _on_area_entered(area: Area2D) -> void:
	var hit_box: HitBoxScript = area as HitBoxScript
	if hit_box == null:
		return

	if hit_box.team == team and team != StringName():
		return

	hit_received.emit(hit_box)