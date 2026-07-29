extends TextureRect

@export var source_viewport: SubViewport


func _ready() -> void:
	if source_viewport != null:
		texture = source_viewport.get_texture()
