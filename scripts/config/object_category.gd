extends Resource
class_name ObjectCategory

@export var display_name: StringName
@export var key: StringName
@export var label_name: StringName
@export var class_id: int = -1
@export var is_unknown: bool = false
@export var enabled: bool = true
@export_range(0.0, 10.0, 0.1) var weight: float = 1.0
@export var scenes: Array[PackedScene] = []


func has_spawnable_scenes() -> bool:
	return enabled and weight > 0.0 and not scenes.is_empty()
