extends Resource
class_name ObjectCatalog

@export var table_class_id: int = 0
@export var unknown_class_id: int = 19
@export var categories: Array[ObjectCategory] = []


func get_class_mapping() -> Dictionary:
	var mapping := {
		"Table": table_class_id,
		"Unknown": unknown_class_id,
	}
	for category in categories:
		if category == null:
			continue
		mapping[String(category.label_name)] = category.class_id
	return mapping


func get_available_categories() -> Array[ObjectCategory]:
	var available: Array[ObjectCategory] = []
	for category in categories:
		if category != null and category.has_spawnable_scenes():
			available.append(category)
	return available


func get_official_categories() -> Array[ObjectCategory]:
	var result: Array[ObjectCategory] = []
	for category in categories:
		if category != null and not category.is_unknown and category.class_id != 0:
			result.append(category)
	return result


func get_unknown_categories() -> Array[ObjectCategory]:
	var result: Array[ObjectCategory] = []
	for category in categories:
		if category != null and category.is_unknown:
			result.append(category)
	return result


func get_category_by_key(key: StringName) -> ObjectCategory:
	for category in categories:
		if category != null and category.key == key:
			return category
	return null
