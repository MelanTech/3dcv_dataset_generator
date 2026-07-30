extends Node

const DEFAULT_CATALOG: ObjectCatalog = preload("res://resources/object_catalog.tres")

var catalog: ObjectCatalog = DEFAULT_CATALOG
var class_mapping: Dictionary = catalog.get_class_mapping()


func get_unknown_class_id() -> int:
	return catalog.unknown_class_id
