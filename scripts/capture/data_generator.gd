extends Node

const CaptureViewportRigScript = preload("res://scripts/capture/capture_viewport_rig.gd")
const CaptureWriterScript = preload("res://scripts/capture/capture_writer.gd")
const LabelGeneratorScript = preload("res://scripts/capture/label_generator.gd")

@export var camera: Camera3D
@export var table: RigidBody3D
@export var depth_view: SubViewport
@export var object_container: Node
@export var base_path: StringName = &"D:/资料/数据集/3DCV生成数据集"
@export var save_interval: int = 30
@export var save_depth: bool = false
@export var save_without_bbox_layer: bool = true
# RGB 保存分辨率（固定，不随窗口大小变化）
@export var rgb_capture_size: Vector2i = Vector2i(640, 480)

# 可见点比例阈值（0-100），低于此比例则丢弃标签。
@export_range(0, 100, 5) var visibility_threshold: int = 20
@export_enum("Grid", "Bounds Key Points", "Hybrid") var occlusion_sample_mode: int = 1
@export var occlusion_grid_sample_count: int = 10  # 仅 Grid / Hybrid 模式使用
@export var debug_occlusion: bool = false
@export var drop_below_table_threshold: float = 0.35

var folder_name: StringName
var rgb_image_path: StringName
var depth_image_path: StringName
var label_path: StringName
var frame_index: int = 0
var frame_count: int = 0
var labels: Array = []
var _saving: bool = false
var _capture_rig

# 会话状态：由 SessionController 控制
var running: bool = false
# 实时保存开关：运行中也可切换。false = 只预览不写盘
var save_enabled: bool = false


func _ready() -> void:
	_sync_depth_viewport_world()
	_setup_capture_viewport()


# 进入运行：重置计数，若开启保存则准备新文件夹
func begin() -> void:
	frame_index = 0
	frame_count = 0
	# 每次启动都开新文件夹：清空上次路径，交给 ensure_output_dirs 重建
	rgb_image_path = &""
	label_path = &""
	depth_image_path = &""
	running = true


# 停止运行
func halt() -> void:
	running = false


func _process(_delta: float) -> void:
	if not running:
		return

	if _saving:
		frame_index += 1
		return

	if save_enabled and frame_index % save_interval == 0 and frame_index > 0:
		var file_name := generate_filename(frame_count)
		_saving = true
		await save_image("{0}.{1}".format([file_name, "jpg"]))
		refresh_labels()
		save_labels("{0}.{1}".format([file_name, "txt"]), labels)
		frame_count += 1
		_saving = false

	frame_index += 1


func refresh_labels() -> void:
	labels = get_all_labels()


func ensure_output_dirs() -> void:
	if not rgb_image_path.is_empty() and not label_path.is_empty():
		return

	folder_name = generate_time_based_folder_name()
	var session_path := str(base_path).path_join(folder_name)
	rgb_image_path = session_path.path_join("images")
	depth_image_path = session_path.path_join("images_depth")
	label_path = session_path.path_join("labels")
	DirAccess.make_dir_recursive_absolute(rgb_image_path)
	if save_depth:
		DirAccess.make_dir_recursive_absolute(depth_image_path)
	DirAccess.make_dir_recursive_absolute(label_path)
	CaptureWriterScript.save_classes(session_path, _get_class_mapping())


func save_image(file_name: String) -> void:
	ensure_output_dirs()

	var capture_viewport := get_viewport()
	if save_without_bbox_layer:
		_prepare_clean_capture_viewport()
		capture_viewport = _capture_rig.viewport
		await RenderingServer.frame_post_draw

	var rgb_image: Image = CaptureWriterScript.capture_viewport_image(capture_viewport)

	# 用较低 JPEG 质量保存，制造真实照片放大后可见的 8x8 压缩块/锯齿
	CaptureWriterScript.save_rgb_jpg(rgb_image, rgb_image_path.path_join(file_name), 0.6)
	if save_depth:
		_sync_depth_viewport_world()
		var depth_image: Image = CaptureWriterScript.capture_viewport_image(depth_view)
		var depth_name := file_name.get_basename() + ".png"
		CaptureWriterScript.save_depth_gray16(depth_image, depth_image_path.path_join(depth_name))
	print("已保存 %s" % file_name)


func save_labels(file_name: String, target_labels: Array) -> void:
	CaptureWriterScript.save_labels(label_path.path_join(file_name), get_viewport().size, target_labels)


func get_all_labels() -> Array:
	return LabelGeneratorScript.get_all_labels(
		camera,
		table,
		object_container,
		_get_unknown_class_id(),
		_get_active_world_3d(),
		visibility_threshold,
		occlusion_sample_mode,
		occlusion_grid_sample_count,
		debug_occlusion,
		drop_below_table_threshold
	)


func _setup_capture_viewport() -> void:
	_capture_rig = CaptureViewportRigScript.new()
	_capture_rig.setup(
		self,
		rgb_capture_size,
		_get_active_world_3d(),
		get_node_or_null("../PostProcess") as CanvasLayer,
		get_node_or_null("../CameraImageAugmenter")
	)


func _prepare_clean_capture_viewport() -> void:
	if _capture_rig == null:
		_setup_capture_viewport()
	_capture_rig.prepare(rgb_capture_size, _get_active_world_3d(), camera)


func _get_active_world_3d() -> World3D:
	if camera != null:
		var camera_world := camera.get_world_3d()
		if camera_world != null:
			return camera_world

	var viewport := get_viewport()
	if viewport != null:
		return viewport.get_world_3d()

	return null


func _sync_depth_viewport_world() -> void:
	if depth_view == null:
		return
	var world := _get_active_world_3d()
	if world != null:
		depth_view.world_3d = world


func _get_class_map_node() -> Node:
	return get_node("/root/ClassMap")


func _get_class_mapping() -> Dictionary:
	return _get_class_map_node().class_mapping


func _get_unknown_class_id() -> int:
	var class_map := _get_class_map_node()
	if class_map.has_method("get_unknown_class_id"):
		return class_map.get_unknown_class_id()
	return _get_class_mapping()["Unknown"]


func generate_time_based_folder_name() -> String:
	var now := Time.get_datetime_dict_from_system()

	var year := str(now.year)
	var month := str(100 + now.month).right(2)
	var day := str(100 + now.day).right(2)
	var hour := str(100 + now.hour).right(2)
	var minute := str(100 + now.minute).right(2)
	var second := str(100 + now.second).right(2)

	return "%s%s%s_%s%s%s" % [year, month, day, hour, minute, second]


func generate_filename(index: int) -> String:
	return "%06d" % [index]
