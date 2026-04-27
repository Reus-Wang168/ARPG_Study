extends AudioStreamPlayer


func _ready() -> void:
	if not finished.is_connected(_on_finished):
		finished.connect(_on_finished)


func _on_finished() -> void:
	play()