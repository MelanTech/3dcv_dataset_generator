extends SubViewport

func _ready() -> void:
	var parent_viewport := get_parent().get_viewport() if get_parent() != null else null
	if parent_viewport != null:
		world_3d = parent_viewport.get_world_3d()
