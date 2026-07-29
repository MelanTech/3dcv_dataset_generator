extends Control

@export var target: Control
@export var logical_size: Vector2 = Vector2(640, 480)
@export_range(0.1, 4.0, 0.05) var min_scale: float = 0.1
@export_range(0.1, 4.0, 0.05) var max_scale: float = 4.0


func _ready() -> void:
	clip_contents = true
	_update_preview_transform()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_preview_transform()


func _update_preview_transform() -> void:
	if target == null:
		return
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var scale_factor = min(size.x / logical_size.x, size.y / logical_size.y)
	scale_factor = clamp(scale_factor, min_scale, max_scale)

	target.custom_minimum_size = logical_size
	target.size = logical_size
	target.scale = Vector2.ONE * scale_factor
	target.position = (size - logical_size * scale_factor) * 0.5
