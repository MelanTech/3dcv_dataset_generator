extends Node

enum PlacementMode {
	TABLE,
	FLOATING,
}

@export var object_catalog: ObjectCatalog

# 桌子的 MeshInstance3D 引用
@export var table_mesh: MeshInstance3D
@export var target_marker: Node3D

# 物品要放置到的目标节点（如场景中的 Objects 容器）
@export var objects_parent: Node

@export var camera: Camera3D

@export_category("Options")

# 要挂载到物品上的脚本
@export var item_script: Script

@export var placement_mode: int = PlacementMode.TABLE

# 物品数量范围（最小值, 最大值）
@export var item_count_range: Vector2i = Vector2i(3, 7)

# 物品之间的最小距离（决定网格密度）
@export var min_distance_between_items: float = 0.2

# 桌面边距（世界单位）：物品会与桌沿保持这个距离，避免掉下去
@export var edge_margin: float = 0.6

# 物品 Y 轴偏移，防止穿模
@export var y_offset: float = 0.05

# 物品缩放范围（最小值, 最大值）
@export var scale_range: Vector2 = Vector2(0.8, 1.2)

# 是否随机化初始倾斜姿态（除了绕 Y 轴朝向外，额外在 X/Z 轴上倾斜）
@export var random_tilt_enabled: bool = true

# X/Z 轴最大倾斜角度（度）。180 = 完全随机翻滚，物品可能侧躺/倒置
@export_range(0.0, 180.0, 1.0) var max_tilt_degrees: float = 180.0

@export_category("Stacking")

# 开启后，少量物品会被规则地放到其他物品上方，模拟手动轻微错位堆叠
@export var stacking_enabled: bool = true

# 参与上层堆叠的物品比例。0.25 表示大约 1/4 的物品放到其他物品上
@export_range(0.0, 1.0, 0.05) var stack_ratio: float = 0.25

# 第一版主要使用双层堆叠；需要更复杂堆叠时可提高该值
@export_range(1, 4, 1) var max_stack_layers: int = 2

# 上层物品相对支撑物中心的偏移比例，越大越容易靠边
@export_range(0.0, 1.0, 0.05) var stack_offset_ratio: float = 0.25

# 上层物品的最大倾斜角度。保持较小更接近手动摆放
@export_range(0.0, 45.0, 1.0) var stacked_max_tilt_degrees: float = 12.0

# 堆叠模式下，底层物品也限制倾斜，避免支撑物过度翻滚导致不像手动摆放
@export_range(0.0, 45.0, 1.0) var stacked_base_max_tilt_degrees: float = 18.0

# 上层物品底部与支撑物顶部之间的安全间距
@export var stack_y_clearance: float = 0.03

# 摆放完成后等待若干物理帧，再将刚体速度清零并休眠
@export_range(0, 120, 1) var settle_physics_frames: int = 20

@export_category("Floating")

@export var floating_center: Vector3 = Vector3(0.0, 5.2, 0.0)
@export var floating_area_size: Vector3 = Vector3(5.0, 2.8, 5.0)
@export var floating_min_distance_between_items: float = 0.8
@export_range(0.0, 180.0, 1.0) var floating_max_tilt_degrees: float = 180.0
@export var move_target_marker_in_floating: bool = true

var available_categories: Array[ObjectCategory] = []
var table_size := Vector2.ZERO
var _initial_target_marker_position := Vector3.ZERO


func _ready() -> void:
	if camera != null:
		camera.rotation_complete.connect(_on_complete_rotation)

	table_size = get_table_size()
	if table_size == Vector2.ZERO:
		print("无法获取桌子尺寸")
	if target_marker != null:
		_initial_target_marker_position = target_marker.global_position

	# 由 SessionController 控制何时开始摆放，_ready 不再自动放置


# 进入运行：清掉残留并摆一批
func begin() -> void:
	clear_items()
	# 桌子形状可能在 Idle 期间被切换，重新取一次尺寸
	table_size = get_table_size()
	available_categories = get_available_categories()
	if available_categories.is_empty():
		print("错误：所有类别中都没有添加启用的物品场景")
		return
	if placement_mode == PlacementMode.FLOATING:
		place_floating_items(available_categories)
		return
	if target_marker != null:
		target_marker.global_position = _initial_target_marker_position
	if table_size == Vector2.ZERO:
		print("无法获取桌子尺寸")
		return
	place_items_on_grid(table_size, available_categories)


# 停止运行：清空桌面
func halt() -> void:
	clear_items()


# 清空已放置的物品
func clear_items() -> void:
	if objects_parent == null:
		return
	for obj in objects_parent.get_children():
		obj.queue_free()


# 获取桌子在 XZ 平面上的一半尺寸（基于 AABB，并计入节点的全局缩放）
func get_table_size() -> Vector2:
	if table_mesh == null or table_mesh.mesh == null:
		return Vector2.ZERO
	var aabb := table_mesh.mesh.get_aabb()
	# AABB 是网格本地尺寸，桌面网格实际带有缩放，需乘上全局缩放才是世界尺寸
	var global_scale := table_mesh.global_transform.basis.get_scale()
	return Vector2(aabb.size.x * global_scale.x, aabb.size.z * global_scale.z) / 2


# 收集所有启用且有物品场景的类别
func get_available_categories() -> Array[ObjectCategory]:
	if object_catalog == null:
		push_error("RandomPlacer 未配置 object_catalog")
		return []
	return object_catalog.get_available_categories()


# 按权重从可用类别中加权随机选取一个类别
func pick_weighted_category(categories: Array[ObjectCategory]) -> ObjectCategory:
	var total_weight := 0.0
	for category in categories:
		total_weight += category.weight
	# 权重总和异常时退化为均匀随机
	if total_weight <= 0.0:
		return categories[randi() % categories.size()]

	var roll := randf() * total_weight
	var acc := 0.0
	for category in categories:
		acc += category.weight
		if roll < acc:
			return category
	return categories[categories.size() - 1]


# 使用网格方式放置物品
func place_items_on_grid(table_half_size: Vector2, categories: Array[ObjectCategory]) -> void:
	var cell_size := min_distance_between_items
	# 预留边距，物品在缩小后的可用区域内摆放，避免贴边掉落
	var half_width: float = max(cell_size * 0.5, table_half_size.x - edge_margin)  # 桌子 X 方向半长
	var half_depth: float = max(cell_size * 0.5, table_half_size.y - edge_margin)  # 桌子 Z 方向半宽

	# 计算网格行列数
	var cols: int = max(1, int(floor(half_width * 2 / cell_size)))
	var rows: int = max(1, int(floor(half_depth * 2 / cell_size)))

	# 创建所有格子的坐标列表
	var grid_cells: Array[Vector2i] = []
	for row in range(rows):
		for col in range(cols):
			grid_cells.append(Vector2i(col, row))

	# 随机打乱格子顺序
	grid_cells.shuffle()

	# 从范围内随机选择物品数量
	var min_count: int = max(1, item_count_range.x)
	var max_count: int = max(min_count, item_count_range.y)
	var target_count: int = randi() % (max_count - min_count + 1) + min_count

	# 实际可放置的最大数量（受限于格子数量）
	var max_items: int = min(target_count, grid_cells.size())
	var table_top_y := get_table_top_y()
	var stack_count := _calculate_stack_count(max_items)
	var base_count := max_items - stack_count
	var placed_count := 0
	var stacked_placed_count := 0
	var support_records: Array[Dictionary] = []

	for i in range(base_count):
		var local_position := _get_cell_local_position(grid_cells[i], half_width, half_depth, cell_size)
		var item := _create_item(categories, false)
		if item == null:
			continue
		var world_xz := Vector2(
			table_mesh.global_position.x + local_position.x,
			table_mesh.global_position.z + local_position.y
		)
		_place_item_bottom_at(item, world_xz, table_top_y + _get_base_y_clearance())
		support_records.append({"node": item, "layer": 1})
		placed_count += 1

	for i in range(stack_count):
		var support_record := _pick_stack_support(support_records)
		if support_record.is_empty():
			break

		var support := support_record["node"] as Node3D
		if support == null or not is_instance_valid(support):
			continue

		var support_bounds := get_node_world_bounds(support)
		var support_center := support_bounds.position + support_bounds.size * 0.5
		var offset_radius: float = min(support_bounds.size.x, support_bounds.size.z) * stack_offset_ratio
		var offset_angle := randf_range(0.0, TAU)
		var offset_distance := randf_range(0.0, offset_radius)
		var world_xz := _clamp_world_xz_to_table(
			Vector2(
				support_center.x + cos(offset_angle) * offset_distance,
				support_center.z + sin(offset_angle) * offset_distance
			),
			half_width,
			half_depth
		)

		var item := _create_item(categories, true)
		if item == null:
			continue

		var support_top_y := support_bounds.position.y + support_bounds.size.y
		_place_item_bottom_at(item, world_xz, support_top_y + stack_y_clearance)

		var next_layer: int = int(support_record["layer"]) + 1
		support_records.append({"node": item, "layer": next_layer})
		placed_count += 1
		stacked_placed_count += 1

	if settle_physics_frames > 0:
		call_deferred("_settle_items_after_frames")

	print("成功放置 ", placed_count, " 个物品，其中堆叠 ", stacked_placed_count, " 个")


func _calculate_stack_count(max_items: int) -> int:
	if not stacking_enabled or max_stack_layers <= 1 or max_items <= 1:
		return 0
	return clampi(int(round(float(max_items) * stack_ratio)), 0, max_items - 1)


func _get_cell_local_position(cell: Vector2i, half_width: float, half_depth: float, cell_size: float) -> Vector2:
	# 计算格子中心在桌子局部坐标系中的位置
	var x: float = -half_width + (cell.x + 0.5) * cell_size
	var z: float = -half_depth + (cell.y + 0.5) * cell_size

	# 在格子内加一点随机偏移（避免完全对齐）
	var jitter := cell_size * 0.4
	x += randf_range(-jitter, jitter)
	z += randf_range(-jitter, jitter)
	return Vector2(x, z)


func _create_item(categories: Array[ObjectCategory], stacked: bool) -> Node3D:
	# 按采样权重随机选择一个可用类别
	var selected_category: ObjectCategory = pick_weighted_category(categories)
	# 从选中类别中随机选择一个物品场景
	var item_scene: PackedScene = selected_category.scenes[randi() % selected_category.scenes.size()]

	var item := item_scene.instantiate() as Node3D
	if item == null:
		return null
	objects_parent.add_child(item)

	var scale_value := randf_range(scale_range.x, scale_range.y)
	item.scale = Vector3(scale_value, scale_value, scale_value)
	item.global_rotation = _get_item_rotation(stacked)

	if item_script != null:
		item.set_script(item_script)
	item.set("classes", selected_category.class_id)
	_reset_body_motion(item)
	return item


func place_floating_items(categories: Array[ObjectCategory]) -> void:
	if move_target_marker_in_floating and target_marker != null:
		target_marker.global_position = floating_center

	var min_count: int = max(1, item_count_range.x)
	var max_count: int = max(min_count, item_count_range.y)
	var target_count: int = randi() % (max_count - min_count + 1) + min_count
	var positions: Array[Vector3] = []
	var placed_count := 0

	for i in range(target_count):
		var position := _pick_floating_position(positions)
		positions.append(position)

		var item := _create_item(categories, false)
		if item == null:
			continue

		item.global_position = position
		item.global_rotation = _get_floating_item_rotation()
		_freeze_body(item)
		placed_count += 1

	print("成功悬浮放置 ", placed_count, " 个物品")


func _pick_floating_position(existing_positions: Array[Vector3]) -> Vector3:
	var attempts := 40
	for i in range(attempts):
		var position := _random_floating_position()
		if _is_far_enough(position, existing_positions, floating_min_distance_between_items):
			return position
	return _random_floating_position()


func _random_floating_position() -> Vector3:
	var half_size := floating_area_size * 0.5
	return floating_center + Vector3(
		randf_range(-half_size.x, half_size.x),
		randf_range(-half_size.y, half_size.y),
		randf_range(-half_size.z, half_size.z)
	)


func _is_far_enough(position: Vector3, existing_positions: Array[Vector3], min_distance: float) -> bool:
	for existing_position in existing_positions:
		if position.distance_to(existing_position) < min_distance:
			return false
	return true


func _get_floating_item_rotation() -> Vector3:
	var tilt := deg_to_rad(floating_max_tilt_degrees)
	return Vector3(
		randf_range(-tilt, tilt),
		randf_range(0.0, PI * 2.0),
		randf_range(-tilt, tilt)
	)


func _get_item_rotation(stacked: bool) -> Vector3:
	var yaw := randf_range(0.0, PI * 2.0)
	if not random_tilt_enabled:
		return Vector3(0.0, yaw, 0.0)

	var tilt_degrees := max_tilt_degrees
	if stacked:
		tilt_degrees = stacked_max_tilt_degrees
	elif stacking_enabled:
		tilt_degrees = min(max_tilt_degrees, stacked_base_max_tilt_degrees)
	var tilt := deg_to_rad(tilt_degrees)
	return Vector3(
		randf_range(-tilt, tilt),
		yaw,
		randf_range(-tilt, tilt)
	)


func _get_base_y_clearance() -> float:
	if stacking_enabled:
		return stack_y_clearance
	return y_offset


func _place_item_bottom_at(item: Node3D, world_xz: Vector2, target_bottom_y: float) -> void:
	item.global_position = Vector3(world_xz.x, target_bottom_y, world_xz.y)
	var bounds := get_node_world_bounds(item)
	item.global_position.y += target_bottom_y - bounds.position.y


func _pick_stack_support(support_records: Array[Dictionary]) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for record in support_records:
		var support := record["node"] as Node3D
		var layer := int(record["layer"])
		if support != null and is_instance_valid(support) and layer < max_stack_layers:
			candidates.append(record)

	if candidates.is_empty():
		return {}
	return candidates[randi() % candidates.size()]


func _clamp_world_xz_to_table(world_xz: Vector2, half_width: float, half_depth: float) -> Vector2:
	var table_center := Vector2(table_mesh.global_position.x, table_mesh.global_position.z)
	return Vector2(
		clamp(world_xz.x, table_center.x - half_width, table_center.x + half_width),
		clamp(world_xz.y, table_center.y - half_depth, table_center.y + half_depth)
	)


func get_table_top_y() -> float:
	var bounds := get_node_world_bounds(table_mesh)
	if bounds.size == Vector3.ZERO:
		return table_mesh.global_position.y
	return bounds.position.y + bounds.size.y


func get_node_world_bounds(node: Node3D) -> AABB:
	var vertices: Array[Vector3] = []
	_collect_collision_shape_world_vertices(node, vertices)
	if vertices.is_empty():
		_collect_mesh_aabb_world_vertices(node, vertices)
	if vertices.is_empty():
		return AABB(node.global_position, Vector3.ZERO)

	var min_corner := vertices[0]
	var max_corner := vertices[0]
	for vertex in vertices:
		min_corner.x = min(min_corner.x, vertex.x)
		min_corner.y = min(min_corner.y, vertex.y)
		min_corner.z = min(min_corner.z, vertex.z)
		max_corner.x = max(max_corner.x, vertex.x)
		max_corner.y = max(max_corner.y, vertex.y)
		max_corner.z = max(max_corner.z, vertex.z)
	return AABB(min_corner, max_corner - min_corner)


func _collect_collision_shape_world_vertices(node: Node, vertices: Array[Vector3]) -> void:
	if node is CollisionShape3D:
		var collision_shape := node as CollisionShape3D
		if collision_shape.shape != null and not collision_shape.disabled:
			vertices.append_array(_get_collision_shape_vertices(collision_shape))

	for child in node.get_children():
		_collect_collision_shape_world_vertices(child, vertices)


func _get_collision_shape_vertices(collision_shape: CollisionShape3D) -> Array[Vector3]:
	var vertices: Array[Vector3] = []
	var shape := collision_shape.shape
	if shape is ConvexPolygonShape3D:
		for point in shape.get_points():
			vertices.append(collision_shape.global_transform * point)
	elif shape is BoxShape3D:
		var half_extents: Vector3 = shape.size / 2.0
		_append_box_vertices(vertices, collision_shape.global_transform, -half_extents, half_extents)
	return vertices


func _collect_mesh_aabb_world_vertices(node: Node, vertices: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var aabb := mesh_instance.mesh.get_aabb()
			_append_box_vertices(
				vertices,
				mesh_instance.global_transform,
				aabb.position,
				aabb.position + aabb.size
			)

	for child in node.get_children():
		_collect_mesh_aabb_world_vertices(child, vertices)


func _append_box_vertices(vertices: Array[Vector3], transform: Transform3D, min_corner: Vector3, max_corner: Vector3) -> void:
	var local_vertices := [
		Vector3(min_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, max_corner.y, max_corner.z),
		Vector3(min_corner.x, max_corner.y, max_corner.z),
	]
	for vertex in local_vertices:
		vertices.append(transform * vertex)


func _reset_body_motion(item: Node3D) -> void:
	_reset_body_motion_recursive(item)


func _freeze_body(item: Node3D) -> void:
	_freeze_body_recursive(item)


func _reset_body_motion_recursive(node: Node) -> void:
	if node is RigidBody3D:
		var body := node as RigidBody3D
		body.freeze = false
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = false

	for child in node.get_children():
		_reset_body_motion_recursive(child)


func _freeze_body_recursive(node: Node) -> void:
	if node is RigidBody3D:
		var body := node as RigidBody3D
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.freeze = true
		body.sleeping = true

	for child in node.get_children():
		_freeze_body_recursive(child)


func _settle_items_after_frames() -> void:
	for i in range(settle_physics_frames):
		await get_tree().physics_frame

	if objects_parent == null:
		return
	for obj in objects_parent.get_children():
		var body := obj as RigidBody3D
		if body == null:
			continue
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
		body.sleeping = true


func _on_complete_rotation(_rotation: int) -> void:
	# 相机待命时不响应（正常情况下 Idle 相机不会转、不会发信号，这里做防御）
	if camera == null or not camera.active:
		return

	clear_items()

	# 重新获取可用类别（可能有变动）
	available_categories = get_available_categories()

	if not available_categories.is_empty():
		if placement_mode == PlacementMode.FLOATING:
			place_floating_items(available_categories)
		else:
			place_items_on_grid(table_size, available_categories)
