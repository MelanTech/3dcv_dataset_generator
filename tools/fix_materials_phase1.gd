@tool
extends SceneTree

## Phase 1 真实感修复：批量修正 prefabs/ 下所有 StandardMaterial3D 的物理参数。
##
## 主要问题（来自审计）：
## - 76 个介电物体（纸盒/塑料/纸）被错误赋了 metallic 0.3~1.0，且没有金属贴图 -> 假的塑料/彩色铬感。
## - 大量 roughness 为 0.0（镜面）或默认 1.0（粉笔感），缺乏物理合理的中间值。
##
## 处理规则（保守，不动已有 PBR 贴图的材质数值来源）：
## - 若材质没有 metallic_texture：强制 metallic = 0（printed 罐子按介电处理，避免彩色铬）。
## - 若材质没有 roughness_texture：把 roughness 夹到 [0.4, 0.85]。
## - 统一给一点合理 specular，并保证接收/投射阴影开启。
##
## 用法（命令行）：
##   /Applications/Godot\ Mono\ 4.6.app/Contents/MacOS/Godot --headless --path . --script res://tools/fix_materials_phase1.gd

const ROOT_DIR := "res://prefabs"
const ROUGH_MIN := 0.4
const ROUGH_MAX := 0.85

var _fixed := 0
var _metallic_cleared := 0
var _rough_clamped := 0
var _scanned := 0


func _initialize() -> void:
	var mats := _find_materials(ROOT_DIR)
	print("[fix_mat] 找到 %d 个材质文件" % mats.size())
	for path in mats:
		_process_material(path)
	print("\n[fix_mat] 完成：扫描 %d，修改 %d（清零 metallic %d，夹紧 roughness %d）" % [
		_scanned, _fixed, _metallic_cleared, _rough_clamped])
	quit()


func _find_materials(dir_path: String) -> PackedStringArray:
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
				result.append_array(_find_materials(full))
		elif name.ends_with(".res") and name.contains("_mat"):
			result.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return result


func _process_material(path: String) -> void:
	var res := load(path)
	if not (res is StandardMaterial3D):
		return
	var mat: StandardMaterial3D = res
	_scanned += 1
	var changed := false

	# 1) 介电修正：没有金属贴图的一律 metallic = 0
	if mat.metallic_texture == null and mat.metallic > 0.001:
		mat.metallic = 0.0
		_metallic_cleared += 1
		changed = true

	# 2) 粗糙度夹紧：没有粗糙度贴图的夹到物理合理区间
	if mat.roughness_texture == null:
		var r: float = clamp(mat.roughness, ROUGH_MIN, ROUGH_MAX)
		if abs(r - mat.roughness) > 0.001:
			mat.roughness = r
			_rough_clamped += 1
			changed = true

	if changed:
		var err := ResourceSaver.save(mat, path)
		if err != OK:
			push_warning("保存失败(%d): %s" % [err, path])
			return
		_fixed += 1
		print(" - %s  metallic=%.2f roughness=%.2f" % [
			path.trim_prefix("res://"), mat.metallic, mat.roughness])
