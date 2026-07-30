extends Control

@export var base_window_size: Vector2i = Vector2i(1120, 540)
@export_range(0.5, 1.0, 0.01) var screen_fill_ratio: float = 0.78
@export_range(0.8, 1.0, 0.01) var max_screen_fill_ratio: float = 0.92
@export var reference_screen_height: float = 1080.0
@export_range(1.0, 2.0, 0.05) var min_ui_scale: float = 1.0
@export_range(1.0, 2.0, 0.05) var max_ui_scale: float = 1.55
@export var center_window: bool = true


func _ready() -> void:
	call_deferred("_apply_responsive_window")


func _apply_responsive_window() -> void:
	var window := get_window()
	if window == null:
		return

	var screen := DisplayServer.window_get_current_screen()
	var usable_rect := DisplayServer.screen_get_usable_rect(screen)
	var usable_size := usable_rect.size
	if usable_size.x <= 0 or usable_size.y <= 0:
		return

	var ui_scale := _calculate_ui_scale(usable_size)
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_factor = ui_scale

	DisplayServer.window_set_min_size(Vector2i(Vector2(base_window_size) * ui_scale))
	var target_size := _calculate_window_size(usable_size, ui_scale)
	DisplayServer.window_set_size(target_size)
	if center_window:
		var position := usable_rect.position + (usable_size - target_size) / 2
		DisplayServer.window_set_position(position)


func _calculate_ui_scale(screen_size: Vector2i) -> float:
	var height_scale := float(screen_size.y) / reference_screen_height
	return clamp(height_scale, min_ui_scale, max_ui_scale)


func _calculate_window_size(screen_size: Vector2i, ui_scale: float) -> Vector2i:
	var by_scale := Vector2(base_window_size) * ui_scale
	var by_screen := Vector2(screen_size) * screen_fill_ratio
	var max_size := Vector2(screen_size) * max_screen_fill_ratio
	var target := Vector2(
		max(by_scale.x, by_screen.x),
		max(by_scale.y, by_screen.y)
	)
	target.x = min(target.x, max_size.x)
	target.y = min(target.y, max_size.y)
	return Vector2i(round(target.x), round(target.y))
