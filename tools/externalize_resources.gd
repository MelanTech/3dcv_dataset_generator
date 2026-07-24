@tool
extends EditorScript

## 批量把 prefabs/ 下 .tscn 内嵌的 Mesh / Material / Texture / Shape 抽成外部 .res。
## 内嵌资源（尤其是以文本 PackedByteArray 存的 Image/ArrayMesh）会让 .tscn 巨大且加载缓慢，
## 外置为二进制 .res 后场景文件会显著变小、打开更快。
##
## 用法（编辑器内）：打开本文件 -> 菜单 File > Run，或快捷键运行。
## 用法（命令行）：godot --headless --path . --script res://tools/externalize_resources.gd
##
## 说明：
## - 每个场景的抽取产物放在同目录下的 `<场景名>_res/` 文件夹里。
## - 已经是外部资源（带 res:// 路径且不指向本场景）的会跳过。
## - 同一场景内相同资源只存一次。

const ROOT_DIR := "res://prefabs"

var _saved_count := 0
var _scene_count := 0
var _bytes_before := 0
var _bytes_after := 0


func _run() -> void:
	var scenes := _find_scenes(ROOT_DIR)
	print("[externalize] 找到 %d 个场景" % scenes.size())
	for path in scenes:
		_process_scene(path)
	print("\n[externalize] 完成：处理 %d 个场景，外置 %d 个资源" % [_scene_count, _saved_count])
	print("[externalize] .tscn 体积：%.1f MB -> %.1f MB" % [
		_bytes_before / 1048576.0, _bytes_after / 1048576.0])


func _find_scenes(dir_path: String) -> PackedStringArray:
	var result := PackedStringArray()
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("无法打开目录: " + dir_path)
		return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			if not name.begins_with("."):
				result.append_array(_find_scenes(full))
		elif name.ends_with(".tscn"):
			result.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return result


func _process_scene(scene_path: String) -> void:
	var size_before := _file_size(scene_path)

	var packed: PackedScene = load(scene_path)
	if packed == null:
		push_warning("跳过（无法加载）: " + scene_path)
		return
	var root := packed.instantiate()
	if root == null:
		push_warning("跳过（无法实例化）: " + scene_path)
		return

	var out_dir := scene_path.get_basename() + "_res"
	DirAccess.make_dir_recursive_absolute(out_dir)

	var cache := {}  # 原资源 -> 已外置资源，避免重复保存
	_externalize_node(root, out_dir, scene_path.get_file().get_basename(), cache)

	# 重新打包并覆盖保存场景
	var new_packed := PackedScene.new()
	if new_packed.pack(root) != OK:
		push_warning("跳过（打包失败）: " + scene_path)
		root.free()
		return
	var err := ResourceSaver.save(new_packed, scene_path)
	root.free()
	if err != OK:
		push_warning("保存场景失败(%d): %s" % [err, scene_path])
		return

	var size_after := _file_size(scene_path)
	_scene_count += 1
	_bytes_before += size_before
	_bytes_after += size_after
	print(" - %s  %.1fMB -> %.1fMB" % [
		scene_path.trim_prefix("res://"),
		size_before / 1048576.0, size_after / 1048576.0])


func _externalize_node(node: Node, out_dir: String, prefix: String, cache: Dictionary) -> void:
	if node is MeshInstance3D and node.mesh != null:
		node.mesh = _externalize_mesh(node.mesh, out_dir, prefix, cache)
	if node is CollisionShape3D and node.shape != null:
		node.shape = _externalize_res(node.shape, out_dir, "%s_shape" % prefix, cache)
	for child in node.get_children():
		_externalize_node(child, out_dir, prefix, cache)


func _externalize_mesh(mesh: Mesh, out_dir: String, prefix: String, cache: Dictionary) -> Mesh:
	# 先外置 mesh 的表面材质
	if mesh is ArrayMesh:
		for i in mesh.get_surface_count():
			var mat := mesh.surface_get_material(i)
			if mat != null:
				mesh.surface_set_material(i, _externalize_material(mat, out_dir, "%s_mat%d" % [prefix, i], cache))
	return _externalize_res(mesh, out_dir, "%s_mesh" % prefix, cache)


func _externalize_material(mat: Material, out_dir: String, name: String, cache: Dictionary) -> Material:
	# 外置材质里的贴图（这是把内嵌 Image 真正踢出场景的关键）
	if mat is BaseMaterial3D:
		var tex_props := [
			"albedo_texture", "normal_texture", "roughness_texture",
			"metallic_texture", "emission_texture", "ao_texture",
		]
		for p in tex_props:
			var tex = mat.get(p)
			if tex is Texture2D:
				mat.set(p, _externalize_res(tex, out_dir, "%s_%s" % [name, p], cache))
	return _externalize_res(mat, out_dir, name, cache)


func _externalize_res(res: Resource, out_dir: String, name: String, cache: Dictionary) -> Resource:
	if res == null:
		return res
	if cache.has(res):
		return cache[res]
	# 已经是独立外部资源就不动
	var existing := res.resource_path
	if existing != "" and not existing.contains("::"):
		cache[res] = res
		return res

	var ext := "res"
	var target := out_dir.path_join("%s.%s" % [name, ext])
	var err := ResourceSaver.save(res, target)
	if err != OK:
		push_warning("保存资源失败(%d): %s" % [err, target])
		cache[res] = res
		return res
	var loaded := load(target)
	cache[res] = loaded
	_saved_count += 1
	return loaded


func _file_size(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	var s := f.get_length()
	f.close()
	return s
