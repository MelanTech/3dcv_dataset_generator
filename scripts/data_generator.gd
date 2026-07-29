extends Node

@export var enable: bool = false
@export var camera: Camera3D
@export var table: RigidBody3D
@export var depth_view: SubViewport
@export var object_container: Node
@export var base_path: StringName = &"D:/资料/数据集/3DCV生成数据集"
@export var auto_save: bool = false
@export var save_interval: int = 30
@export var save_depth: bool = false
@export var save_without_bbox_layer: bool = true
# RGB 保存分辨率（固定，不随窗口大小变化）
@export var rgb_capture_size: Vector2i = Vector2i(640, 480)

# 遮挡检测射线数量（越多越精确，性能消耗越大）
@export var ray_count: int = 10  # 建议10-20个点平衡精度和性能

# 遮挡阈值（0-100），超过此百分比则视为需要忽略的遮挡
@export_range(0, 100, 5) var occlusion_threshold: int = 70

@export var max_generate_frame: int = 0

var folder_name: StringName
var rgb_image_path: StringName
var depth_image_path: StringName
var label_path: StringName
var frame_index: int = 0
var frame_count: int = 0
var labels: Array = []
var _saving: bool = false
var _capture_viewport: SubViewport
var _capture_camera: Camera3D
var _capture_post_process: CanvasLayer

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

func _process(delta: float) -> void:
	if not running:
		return

	if _saving:
		frame_index += 1
		return

	if save_enabled and frame_index % save_interval == 0 and frame_index > 0:
		var file_name = generate_filename(frame_count)
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
	var session_path = str(base_path).path_join(folder_name)
	rgb_image_path = session_path.path_join("images")
	depth_image_path = session_path.path_join("images_depth")
	label_path = session_path.path_join("labels")
	DirAccess.make_dir_recursive_absolute(rgb_image_path)
	if save_depth:
		DirAccess.make_dir_recursive_absolute(depth_image_path)
	DirAccess.make_dir_recursive_absolute(label_path)
	save_classes(session_path)
		
func save_image(file_name) -> void:
	ensure_output_dirs()

	var capture_viewport := get_viewport()
	if save_without_bbox_layer:
		_prepare_clean_capture_viewport()
		capture_viewport = _capture_viewport
		await RenderingServer.frame_post_draw

	var rgb_image = capture_viewport_image(capture_viewport)

	# 用较低 JPEG 质量保存，制造真实照片放大后可见的 8x8 压缩块/锯齿
	rgb_image.save_jpg(rgb_image_path.path_join(file_name), 0.6)
	if save_depth:
		_sync_depth_viewport_world()
		var depth_image = capture_viewport_image(depth_view)
		# 深度 shader 把毫米拆成 R(高字节)/G(低字节)，还原为单通道 16-bit 灰度 PNG，
		# 与 OpenNI 深度相机输出一致（bitdepth=16, colortype=0，像素值=毫米）
		var depth_name = file_name.get_basename() + ".png"
		_save_depth_gray16(depth_image, depth_image_path.path_join(depth_name))
	print("已保存 %s" % file_name)

func _setup_capture_viewport() -> void:
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "CleanCaptureViewport"
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_capture_viewport.world_3d = _get_active_world_3d()
	_capture_viewport.size = rgb_capture_size
	add_child(_capture_viewport)

	_capture_camera = Camera3D.new()
	_capture_camera.name = "CleanCaptureCamera"
	_capture_viewport.add_child(_capture_camera)

	var source_post_process := get_node_or_null("../PostProcess") as CanvasLayer
	if source_post_process != null:
		_capture_post_process = CanvasLayer.new()
		_capture_post_process.name = "CleanCapturePostProcess"
		_capture_post_process.set_script(load("res://addons/post_processing/node/post_process.gd"))
		_capture_post_process.set("configuration", source_post_process.get("configuration"))
		_capture_post_process.set("dynamically_update", source_post_process.get("dynamically_update"))
		_capture_post_process.layer = source_post_process.layer
		_capture_post_process.custom_viewport = _capture_viewport
		_capture_viewport.add_child(_capture_post_process)

func _prepare_clean_capture_viewport() -> void:
	if _capture_viewport == null:
		_setup_capture_viewport()

	_capture_viewport.size = rgb_capture_size
	_capture_viewport.world_3d = _get_active_world_3d()
	_sync_capture_camera()
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _sync_capture_camera() -> void:
	if camera == null or _capture_camera == null:
		return

	_capture_camera.global_transform = camera.global_transform
	_capture_camera.keep_aspect = camera.keep_aspect
	_capture_camera.cull_mask = camera.cull_mask
	_capture_camera.environment = camera.environment
	_capture_camera.attributes = camera.attributes
	_capture_camera.doppler_tracking = camera.doppler_tracking
	_capture_camera.projection = camera.projection
	_capture_camera.current = true

	match camera.projection:
		Camera3D.PROJECTION_PERSPECTIVE:
			_capture_camera.fov = camera.fov
			_capture_camera.near = camera.near
			_capture_camera.far = camera.far
		Camera3D.PROJECTION_ORTHOGONAL:
			_capture_camera.size = camera.size
			_capture_camera.near = camera.near
			_capture_camera.far = camera.far
		Camera3D.PROJECTION_FRUSTUM:
			_capture_camera.size = camera.size
			_capture_camera.frustum_offset = camera.frustum_offset
			_capture_camera.near = camera.near
			_capture_camera.far = camera.far
	
func save_labels(file_name:String, labels):
	var window_size = get_viewport().size
	var file = FileAccess.open(label_path.path_join(file_name), FileAccess.WRITE)
	
	for label in labels:
		var cls = label['class']
		var bbox = label['bbox']
		bbox = _xyxy2cxywh(bbox)
		file.store_line("{0} {1} {2} {3} {4}".format([
			cls, bbox[0] / window_size[0], 
			bbox[1] / window_size[1], 
			bbox[2] / window_size[0], 
			bbox[3] / window_size[1]
		]))
		
	file.close()
	
func save_classes(session_path: String):
	var class_map = get_node("/root/ClassMap").class_mapping
	var file = FileAccess.open(session_path.path_join("classes.txt"), FileAccess.WRITE)
	var unknown_id = class_map["Unknown"]
	# 按类别 ID 顺序取每个 ID 的规范名称；Unknown 及其下属子类别（值都等于
	# unknown_id）不写入，避免子类别把标签文件行号打乱
	var id_to_name = {}
	for key in class_map.keys():
		var id = class_map[key]
		if id == unknown_id:
			continue
		if not id_to_name.has(id):
			id_to_name[id] = key
	var ids = id_to_name.keys()
	ids.sort()
	for id in ids:
		file.store_line(id_to_name[id])

	file.close()

func capture_viewport_image(viewport: Viewport) -> Image:
	var texture = viewport.get_texture()
	return texture.get_image()

# 把深度 viewport 的 RGB8 图像（R=毫米高字节, G=低字节）还原为单通道
# 16-bit 灰度 PNG（像素值=毫米），格式与 OpenNI 深度相机输出一致。
func _save_depth_gray16(depth_image: Image, path: String) -> void:
	if depth_image.get_format() != Image.FORMAT_RGB8:
		depth_image.convert(Image.FORMAT_RGB8)
	var width := depth_image.get_width()
	var height := depth_image.get_height()
	var data := depth_image.get_data()  # RGB8: 每像素 3 字节
	var samples := PackedInt32Array()
	samples.resize(width * height)
	var src := 0
	for i in range(width * height):
		# R=高字节, G=低字节 -> 毫米
		samples[i] = (data[src] << 8) | data[src + 1]
		src += 3
	var err := DepthPng16.save_gray16(path, samples, width, height)
	if err != OK:
		push_error("深度图 16-bit PNG 保存失败: %s (err=%d)" % [path, err])

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

func generate_time_based_folder_name() -> String:
	var now = Time.get_datetime_dict_from_system()
	
	var year = str(now.year)
	var month = str(100 + now.month).right(2)
	var day = str(100 + now.day).right(2)
	var hour = str(100 + now.hour).right(2)
	var minute = str(100 + now.minute).right(2)
	var second = str(100 + now.second).right(2)
	
	return "%s%s%s_%s%s%s" % [year, month, day, hour, minute, second]
	
func generate_filename(index: int) -> String:
	return "%06d" % [index]
	
func get_all_labels():
	var labels = []
	for obj in object_container.get_children():
		if obj.classes == get_node("/root/ClassMap").class_mapping["Unknown"]:
			continue
		elif obj.position.y < 4.5:
			obj.queue_free()
			continue
		elif is_occluded_above_threshold(obj):
			continue
			
		var bbox = _get_2d_bbox(obj)
		var cls = obj.classes
		labels.append({"bbox": bbox, "class": cls})
		
	labels.append(get_table_label())
	
	return labels
	
func get_table_label():
	var bbox = _get_2d_bbox(table)
	var cls = table.classes
	return {"bbox": bbox, "class": cls}
	
func _xyxy2cxywh(xyxy: Variant) -> Array:
	var x1 = xyxy[0]
	var y1 = xyxy[1]
	var x2 = xyxy[2]
	var y2 = xyxy[3]
	
	# 计算中心坐标
	var center_x = (x1 + x2) / 2.0
	var center_y = (y1 + y2) / 2.0
	
	# 计算宽度和高度
	var width = x2 - x1
	var height = y2 - y1
	
	return [center_x, center_y, width, height]
	
	
func _get_2d_bbox(node: Node3D) -> Array:
	# 获取碰撞形状节点及其变换
	var collision_shape = node.get_child(1) as CollisionShape3D
	if not collision_shape:
		print("找不到有效的CollisionShape3D")
		return []
	
	var shape = collision_shape.shape
	var vertices = PackedVector3Array()
	
	# 获取碰撞形状自身的变换（可能包含缩放、旋转等）
	var shape_transform = collision_shape.transform
	
	# 根据形状类型获取顶点
	if shape is ConvexPolygonShape3D:
		vertices = shape.get_points()
	elif shape is BoxShape3D:
		# 获取BoxShape3D的半尺寸
		var half_extents = shape.size / 2.0
		# 生成Box的8个顶点（本地坐标）
		var local_vertices = PackedVector3Array([
			Vector3(-half_extents.x, -half_extents.y, -half_extents.z),
			Vector3(half_extents.x, -half_extents.y, -half_extents.z),
			Vector3(half_extents.x, half_extents.y, -half_extents.z),
			Vector3(-half_extents.x, half_extents.y, -half_extents.z),
			Vector3(-half_extents.x, -half_extents.y, half_extents.z),
			Vector3(half_extents.x, -half_extents.y, half_extents.z),
			Vector3(half_extents.x, half_extents.y, half_extents.z),
			Vector3(-half_extents.x, half_extents.y, half_extents.z)
		])
		
		# 应用碰撞形状自身的变换
		for vert in local_vertices:
			vertices.append(shape_transform * vert)
	
	# 获取所有顶点并转换到世界空间（应用节点的全局变换）
	var world_vertices = []
	for vertex in vertices:
		world_vertices.append(node.global_transform * vertex)
	
	# 将3D世界坐标投影到相机的2D视口坐标
	var viewport_points = []
	for world_vertex in world_vertices:
		var viewport_point = camera.unproject_position(world_vertex)
		viewport_points.append(viewport_point)
	
	# 如果没有点，返回空
	if viewport_points.is_empty():
		return []
	
	# 计算边界框
	var min_x = viewport_points[0].x
	var max_x = viewport_points[0].x
	var min_y = viewport_points[0].y
	var max_y = viewport_points[0].y
	
	for point in viewport_points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)
	
	return [min_x, min_y, max_x, max_y]


# 检测物体是否被遮挡超过阈值
func is_occluded_above_threshold(object: Node3D) -> bool:
	var mesh = object.get_child(0)
	var aabb = mesh.get_aabb()
	var points = get_detection_points(object, aabb)
	
	# 对每个点发射射线检测遮挡
	var occluded_count = 0
	for point in points:
		if is_point_occluded(point, object):
			occluded_count += 1
	
	# 计算遮挡百分比并与阈值比较
	var occlusion_percentage = (occluded_count / points.size()) * 100
	return occlusion_percentage >= occlusion_threshold

# 获取更均匀分布的检测点
func get_detection_points(object: Node3D, aabb: AABB) -> Array:
	var points = []
	var local_points = []
	
	# 生成均匀分布的点（比单纯顶点更准确）
	var step = 1.0 / (ceil(sqrt(ray_count)) - 1) if ray_count > 1 else 1.0
	
	for i in range(ray_count):
		# 在AABB范围内生成均匀分布的点
		var x = aabb.position.x + fmod(i, ceil(sqrt(ray_count))) * step * aabb.size.x
		var y = aabb.position.y + (i / floor(sqrt(ray_count))) * step * aabb.size.y
		var z = aabb.position.z + aabb.size.z * 0.5  # 取中间高度
		
		local_points.append(Vector3(x, y, z))
	
	# 转换为全局坐标并确保中心点被包含
	var global_center = object.global_position
	points.append(global_center)
	
	for local_point in local_points:
		var global_point = object.to_global(local_point)
		if global_point.distance_to(global_center) > 0.01 and global_point not in points:
			points.append(global_point)
	
	# 确保点数量不超过设定值
	return points.slice(0, ray_count)

# 检测单个点是否被遮挡
func is_point_occluded(point: Vector3, self_object: Node3D) -> bool:
	# 射线起点：相机位置
	var ray_start = camera.global_position
	# 射线终点：物体上的检测点
	var ray_end = point
	
	# 计算相机到检测点的距离
	var total_distance = ray_start.distance_to(ray_end)
	
	if total_distance < 0.001:
		return false  # 点与相机重合，不视为遮挡
	
	# 创建射线查询
	var world := _get_active_world_3d()
	if world == null:
		return false
	var space_state = world.direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	
	# 排除自身（避免检测到自己的碰撞体）
	#var collision_object = self_object.get_node_or_null("CollisionShape3D")
	#query.exclude = [collision_object.get_rid()]
	
	# 执行射线检测
	var result = space_state.intersect_ray(query)
	
	# 如果有碰撞结果，计算碰撞点到相机的距离
	if result:
		var hit_distance = ray_start.distance_to(result.position)
		# 如果碰撞点距离小于总距离（减去微小误差值），说明被遮挡
		return hit_distance < total_distance - 0.1
	
	# 没有碰撞，不遮挡
	return false
