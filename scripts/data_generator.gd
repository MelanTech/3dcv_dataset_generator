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

# 遮挡检测射线数量（越多越精确，性能消耗越大）
@export var ray_count: int = 10  # 建议10-20个点平衡精度和性能

# 遮挡阈值（0-100），超过此百分比则视为需要忽略的遮挡
@export_range(0, 100, 5) var occlusion_threshold: int = 70

@export var max_generate_frame: int = 0

# 深度图 16-bit 毫米编码时使用的世界单位->米系数（须与 depth.gdshader / 材质里的 world_scale 一致）
@export var depth_world_scale: float = 0.0638
# 是否在运行时自动标定 depth_world_scale（用射线取真值，打印建议值）
@export var auto_calibrate_depth: bool = true

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

func _ready() -> void:
	_setup_capture_viewport()

	if enable and auto_save:
		ensure_output_dirs()
		
func _process(delta: float) -> void:
	if _saving:
		frame_index += 1
		return

	if enable and frame_index % save_interval == 0:
		if frame_index > 0:
			var file_name = generate_filename(frame_count)
			if auto_save:
				_saving = true
				await save_image("{0}.{1}" .format([file_name, "jpg"]))
				refresh_labels()
				save_labels("{0}.{1}".format([file_name, "txt"]), labels)
				frame_count += 1
				_saving = false
				
			if max_generate_frame > 0 and frame_count >= max_generate_frame:
				get_tree().quit()
			
	frame_index += 1

func _input(event: InputEvent) -> void:
	if _saving:
		return

	if enable and not auto_save and event is InputEventKey and event.is_action_pressed("ui_screenshot"):
		var file_name = generate_filename(frame_count)
		_saving = true
		await save_image("{0}.{1}" .format([file_name, "jpg"]))
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
	base_path = base_path.path_join(folder_name)
	rgb_image_path = base_path.path_join("images")
	depth_image_path = base_path.path_join("images_depth")
	label_path = base_path.path_join("labels")
	DirAccess.make_dir_recursive_absolute(rgb_image_path)
	if save_depth:
		DirAccess.make_dir_recursive_absolute(depth_image_path)
	DirAccess.make_dir_recursive_absolute(label_path)
	save_classes()
		
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
		var depth_image = capture_viewport_image(depth_view)
		# 深度图为 16-bit 毫米编码（R:高字节, G:低字节），用无损 PNG 保存
		var depth_name = file_name.get_basename() + ".png"
		depth_image.save_png(depth_image_path.path_join(depth_name))
		# 每次保存都标定一次（用于验证不同相机位置下建议值是否一致）
		if auto_calibrate_depth:
			calibrate_depth_scale()
	print("已保存 %s" % file_name)

func _setup_capture_viewport() -> void:
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "CleanCaptureViewport"
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_capture_viewport.world_3d = get_viewport().world_3d
	_capture_viewport.size = get_viewport().size
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

	_capture_viewport.size = get_viewport().size
	_capture_viewport.world_3d = get_viewport().world_3d
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
	
func save_classes():
	var class_map = get_node("/root/ClassMap").class_mapping
	var file = FileAccess.open(base_path.path_join("classes.txt"), FileAccess.WRITE)
	for key in class_map.keys():
		if key == "Unknown":
			continue
		file.store_line(key)
		
	file.close()

func capture_viewport_image(viewport: Viewport) -> Image:
	var texture = viewport.get_texture()
	return texture.get_image()

# 从深度图某像素解码出毫米值：depth_mm = R*256 + G（8-bit 通道承载 16-bit）
func decode_depth_mm(depth_image: Image, x: int, y: int) -> float:
	var c: Color = depth_image.get_pixel(x, y)
	return round(c.r * 255.0) * 256.0 + round(c.g * 255.0)

# 解码为真实米：先还原毫米，再按 shader 未缩放前的量再乘系数已含在 shader 内，这里仅做 mm->m
func decode_depth_meters(depth_image: Image, x: int, y: int) -> float:
	return decode_depth_mm(depth_image, x, y) / 1000.0

# 自动标定：从深度相机沿视线中心发射射线打到桌面，得到真实世界单位距离(真值)，
# 与深度图中心像素解码出的深度对比，反推 depth_world_scale 的建议值。
func calibrate_depth_scale() -> void:
	var depth_cam: Camera3D = _get_depth_camera()
	if depth_cam == null:
		print("[calib] 未找到深度相机，跳过标定")
		return
	var depth_image: Image = capture_viewport_image(depth_view)
	var w: int = depth_image.get_width()
	var h: int = depth_image.get_height()
	var cx: int = w / 2
	var cy: int = h / 2

	# 从深度相机中心像素反投影出射线，物理查询命中的真实距离（世界单位）
	var from: Vector3 = depth_cam.project_ray_origin(Vector2(cx, cy))
	var dir: Vector3 = depth_cam.project_ray_normal(Vector2(cx, cy))
	var space := get_viewport().world_3d.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 10000.0)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		print("[calib] 中心射线未命中物体，跳过标定")
		return

	var true_units: float = depth_cam.global_position.distance_to(hit.position)
	# 当前深度图中心解码出的深度（米），它 = 反投影世界单位深度 * 当前 depth_world_scale
	var decoded_m: float = decode_depth_meters(depth_image, cx, cy)
	if decoded_m <= 0.0:
		print("[calib] 中心像素深度为0，跳过标定")
		return
	# 场景定标：桌面平面 5.5 世界单位 = 0.55m => 1 世界单位 = 0.1m
	var unit_to_meter := 0.1
	var target_m: float = true_units * unit_to_meter
	var suggested_scale: float = depth_world_scale * target_m / decoded_m
	print("[calib] 中心射线命中: 真实=%.3f世界单位(=%.3fm) 当前解码=%.3fm => 建议 depth_world_scale=%.6f" % [
		true_units, target_m, decoded_m, suggested_scale])

func _get_depth_camera() -> Camera3D:
	for child in depth_view.get_children():
		if child is Camera3D:
			return child
	return null

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
	var space_state = get_viewport().get_world_3d().direct_space_state
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
