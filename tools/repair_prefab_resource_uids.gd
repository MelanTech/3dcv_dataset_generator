extends SceneTree

## Repair invalid UID warnings in externalized prefab resources.
##
## Background:
## Some externalized ArrayMesh .res files reference material .res files with stale
## uid:// values. Godot can still load them by path, but prints warnings like:
## "invalid UID ... using text path instead".
##
## This script registers stable ResourceUID entries for prefab .res files and
## re-saves ArrayMesh resources so their material dependencies are written with
## valid UIDs.
##
## Usage:
##   Godot --headless --path . --script res://tools/repair_prefab_resource_uids.gd

const ROOT_DIR := "res://prefabs"

var _registered_count := 0
var _mesh_count := 0
var _saved_mesh_count := 0
var _error_count := 0


func _initialize() -> void:
	var res_files := _find_files(ROOT_DIR, ".res")
	for path in res_files:
		_ensure_uid(path)

	var mesh_files := PackedStringArray()
	for path in res_files:
		if path.ends_with("_mesh.res"):
			mesh_files.append(path)

	for path in mesh_files:
		_process_mesh(path)

	print("[repair_uid] resources=%d registered=%d meshes=%d saved=%d errors=%d" % [
		res_files.size(), _registered_count, _mesh_count, _saved_mesh_count, _error_count
	])
	quit(_error_count)


func _find_files(dir_path: String, suffix: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("Cannot open directory: " + dir_path)
		_error_count += 1
		return result

	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				result.append_array(_find_files(full, suffix))
		elif name.ends_with(suffix):
			result.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return result


func _ensure_uid(path: String) -> void:
	var uid_text := ResourceUID.path_to_uid(path)
	if uid_text.begins_with("uid://"):
		var existing_id := ResourceUID.text_to_id(uid_text)
		if ResourceUID.has_id(existing_id):
			return

	var id := ResourceUID.create_id_for_path(path)
	if ResourceUID.has_id(id):
		ResourceUID.set_id(id, path)
	else:
		ResourceUID.add_id(id, path)
	_registered_count += 1


func _process_mesh(path: String) -> void:
	_mesh_count += 1
	var res := load(path)
	if not (res is ArrayMesh):
		return

	var mesh := res as ArrayMesh
	var changed := false
	for surface_index in mesh.get_surface_count():
		var mat := mesh.surface_get_material(surface_index)
		if mat == null:
			continue

		var mat_path := mat.resource_path
		if mat_path.is_empty():
			continue

		_ensure_uid(mat_path)
		var reloaded_mat := load(mat_path)
		if reloaded_mat != null and reloaded_mat != mat:
			mesh.surface_set_material(surface_index, reloaded_mat)
			changed = true

	# Save even when material object identity did not change. The point is to
	# rewrite external dependency UID metadata using the now-valid ResourceUID map.
	var err := ResourceSaver.save(mesh, path)
	if err != OK:
		push_warning("Failed to save mesh (%d): %s" % [err, path])
		_error_count += 1
		return

	_saved_mesh_count += 1
	if changed:
		print("[repair_uid] rewired " + path)
