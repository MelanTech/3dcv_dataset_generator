extends Node

@export var object_catalog: ObjectCatalog

# 桌子的 MeshInstance3D 引用
@export var table_mesh: MeshInstance3D

# 物品要放置到的目标节点（如场景中的 Objects 容器）
@export var objects_parent: Node

@export var camera: Camera3D

@export_category("Options")

# 要挂载到物品上的脚本
@export var item_script: Script

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

var available_categories: Array[ObjectCategory] = []
var table_size := Vector2.ZERO


func _ready() -> void:
	if camera != null:
		camera.rotation_complete.connect(_on_complete_rotation)

	table_size = get_table_size()
	if table_size == Vector2.ZERO:
		print("无法获取桌子尺寸")

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
	var placed_count := 0

	for i in range(max_items):
		var cell := grid_cells[i]

		# 计算格子中心在桌子局部坐标系中的位置
		var x: float = -half_width + (cell.x + 0.5) * cell_size
		var z: float = -half_depth + (cell.y + 0.5) * cell_size

		# 在格子内加一点随机偏移（避免完全对齐）
		var jitter := cell_size * 0.4
		x += randf_range(-jitter, jitter)
		z += randf_range(-jitter, jitter)

		var position := Vector3(x, y_offset, z)

		# 按采样权重随机选择一个可用类别
		var selected_category: ObjectCategory = pick_weighted_category(categories)
		# 从选中类别中随机选择一个物品场景
		var item_scene: PackedScene = selected_category.scenes[randi() % selected_category.scenes.size()]

		# 实例化物品
		var item := item_scene.instantiate() as Node3D
		objects_parent.add_child(item)

		# 设置位置和旋转
		item.global_position = table_mesh.global_position + position
		if random_tilt_enabled:
			# 完整的随机三轴姿态：先随机朝向(Y)，再在 X/Z 上随机倾斜/翻滚
			var tilt := deg_to_rad(max_tilt_degrees)
			item.global_rotation = Vector3(
				randf_range(-tilt, tilt),
				randf_range(0, PI * 2),
				randf_range(-tilt, tilt)
			)
		else:
			item.global_rotation = Vector3(0, randf_range(0, PI * 2), 0)

		# 设置随机缩放
		var scale_value := randf_range(scale_range.x, scale_range.y)
		item.scale = Vector3(scale_value, scale_value, scale_value)

		# 挂载脚本并设置 classes 属性
		item.set_script(item_script)
		item.classes = selected_category.class_id

		placed_count += 1

	print("成功放置 ", placed_count, " 个物品")


func _on_complete_rotation(_rotation: int) -> void:
	# 相机待命时不响应（正常情况下 Idle 相机不会转、不会发信号，这里做防御）
	if camera == null or not camera.active:
		return

	clear_items()

	# 重新获取可用类别（可能有变动）
	available_categories = get_available_categories()

	if not available_categories.is_empty():
		place_items_on_grid(table_size, available_categories)
