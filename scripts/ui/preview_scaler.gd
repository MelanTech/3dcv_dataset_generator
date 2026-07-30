extends Control

@export var target: Control
@export var targets: Array[Control] = []
@export var logical_size: Vector2 = Vector2(640, 480)
@export var vertical: bool = false
@export_range(0.1, 4.0, 0.05) var min_scale: float = 0.1
@export_range(0.1, 4.0, 0.05) var max_scale: float = 4.0


func _ready() -> void:
	clip_contents = true
	_update_preview_transform()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_preview_transform()


func _update_preview_transform() -> void:
	var preview_targets := _get_preview_targets()
	if preview_targets.is_empty():
		return
	if logical_size.x <= 0.0 or logical_size.y <= 0.0:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return

	var total_size := _get_unscaled_total_size(preview_targets)
	var scale_factor = min(size.x / total_size.x, size.y / total_size.y)
	scale_factor = clamp(scale_factor, min_scale, max_scale)

	var start_x: float = (size.x - logical_size.x * scale_factor) * 0.5
	var start_y: float = (size.y - total_size.y * scale_factor) * 0.5
	var current_x: float = start_x
	var current_y: float = start_y
	for preview_target in preview_targets:
		preview_target.custom_minimum_size = logical_size
		preview_target.size = logical_size
		preview_target.scale = Vector2.ONE * scale_factor
		preview_target.position = Vector2(current_x, current_y)
		if vertical:
			current_y += logical_size.y * scale_factor
		else:
			current_x += logical_size.x * scale_factor


func _get_preview_targets() -> Array[Control]:
	if not targets.is_empty():
		return targets.filter(func(item): return item != null)
	if target != null:
		return [target]
	return []


func _get_unscaled_total_size(preview_targets: Array[Control]) -> Vector2:
	if vertical:
		return Vector2(logical_size.x, logical_size.y * preview_targets.size())
	return Vector2(logical_size.x * preview_targets.size(), logical_size.y)
