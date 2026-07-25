extends Node

@export var enable: bool = true

# 桌子的MeshInstance3D引用
@export var table_mesh: MeshInstance3D

# 物品要放置到的目标节点（如场景中的 Objects 容器）
@export var objects_parent: Node

@export var camera: Camera3D

# 物品类别场景和启用状态 - 按类别分别管理
@export_category("Scenes")
@export var comb_enabled: bool = true
@export var comb_scenes: Array[PackedScene] = []

@export var toothbrush_enabled: bool = true
@export var toothbrush_scenes: Array[PackedScene] = []

@export var paper_cup_enabled: bool = true
@export var paper_cup_scenes: Array[PackedScene] = []

@export var clotheshanger_enabled: bool = true
@export var clotheshanger_scenes: Array[PackedScene] = []

@export var jelly_enabled: bool = true
@export var jelly_scenes: Array[PackedScene] = []

@export var biscuit_enabled: bool = true
@export var biscuit_scenes: Array[PackedScene] = []

@export var sausage_enabled: bool = true
@export var sausage_scenes: Array[PackedScene] = []

@export var chips_enabled: bool = true
@export var chips_scenes: Array[PackedScene] = []

@export var canned_chips_enabled: bool = true
@export var canned_chips_scenes: Array[PackedScene] = []

@export var can_enabled: bool = true
@export var can_scenes: Array[PackedScene] = []

@export var bottle_enabled: bool = true
@export var bottle_scenes: Array[PackedScene] = []

@export var milk_enabled: bool = true
@export var milk_scenes: Array[PackedScene] = []

@export var water_enabled: bool = true
@export var water_scenes: Array[PackedScene] = []

@export var pomegranate_enabled: bool = true
@export var pomegranate_scenes: Array[PackedScene] = []

@export var orange_enabled: bool = true
@export var orange_scenes: Array[PackedScene] = []

@export var banana_enabled: bool = true
@export var banana_scenes: Array[PackedScene] = []

@export var dragon_fruit_enabled: bool = true
@export var dragon_fruit_scenes: Array[PackedScene] = []

@export var book_enabled: bool = true
@export var book_scenes: Array[PackedScene] = []

@export var unknown_enabled: bool = true
@export var unknown_scenes: Array[PackedScene] = []

@export_category("Options")

# 要挂载到物品上的脚本
@export var item_script: Script

# 物品数量范围（最小值, 最大值）
@export var item_count_range: Vector2i = Vector2i(3, 7)

# 物品之间的最小距离（决定网格密度）
@export var min_distance_between_items: float = 0.2

# 桌面边距（世界单位）：物品会与桌沿保持这个距离，避免掉下去
@export var edge_margin: float = 0.6

# 物品Y轴偏移，防止穿模
@export var y_offset: float = 0.05

# 物品缩放范围（最小值, 最大值）
@export var scale_range: Vector2 = Vector2(0.8, 1.2)

# 是否随机化初始倾斜姿态（除了绕Y轴朝向外，额外在X/Z轴上倾斜）
@export var random_tilt_enabled: bool = true

# X/Z轴最大倾斜角度（度）。180 = 完全随机翻滚，物品可能侧躺/倒置
@export_range(0.0, 180.0, 1.0) var max_tilt_degrees: float = 180.0

# 类别与classes值的映射关系
@onready var class_mapping = get_node("/root/ClassMap").class_mapping

var available_classes
var table_size

func _ready():
	camera.rotation_complete.connect(_on_complete_rotation)
	
	# 收集所有可用的物品类别
	available_classes = get_available_classes()
	if available_classes.is_empty():
		print("错误：所有类别中都没有添加启用的物品场景")
		return

	# 获取桌子尺寸
	table_size = get_table_size()
	if table_size == Vector2.ZERO:
		print("无法获取桌子尺寸")
		return

	# 开始放置物品
	if enable:
		place_items_on_grid(table_size, available_classes)


# 获取桌子在XZ平面上的一半尺寸（基于AABB，并计入节点的全局缩放）
func get_table_size() -> Vector2:
	var mesh = table_mesh.mesh
	if not mesh:
		return Vector2.ZERO
	var aabb = mesh.get_aabb()
	# AABB 是网格本地尺寸，桌面网格实际带有缩放，需乘上全局缩放才是世界尺寸
	var gscale = table_mesh.global_transform.basis.get_scale()
	return Vector2(aabb.size.x * gscale.x, aabb.size.z * gscale.z) / 2


# 收集所有启用且有物品场景的类别
func get_available_classes() -> Array:
	var classes = [
		{"name": "Comb", "enabled": comb_enabled, "scenes": comb_scenes},
		{"name": "Toothbrush", "enabled": toothbrush_enabled, "scenes": toothbrush_scenes},
		{"name": "PaperCup", "enabled": paper_cup_enabled, "scenes": paper_cup_scenes},
		{"name": "Clotheshanger", "enabled": clotheshanger_enabled, "scenes": clotheshanger_scenes},
		{"name": "Jelly", "enabled": jelly_enabled, "scenes": jelly_scenes},
		{"name": "Biscuit", "enabled": biscuit_enabled, "scenes": biscuit_scenes},
		{"name": "Sausage", "enabled": sausage_enabled, "scenes": sausage_scenes},
		{"name": "Chips", "enabled": chips_enabled, "scenes": chips_scenes},
		{"name": "CannedChips", "enabled": canned_chips_enabled, "scenes": canned_chips_scenes},
		{"name": "Can", "enabled": can_enabled, "scenes": can_scenes},
		{"name": "Bottle", "enabled": bottle_enabled, "scenes": bottle_scenes},
		{"name": "Milk", "enabled": milk_enabled, "scenes": milk_scenes},
		{"name": "Water", "enabled": water_enabled, "scenes": water_scenes},
		{"name": "Pomegranate", "enabled": pomegranate_enabled, "scenes": pomegranate_scenes},
		{"name": "Orange", "enabled": orange_enabled, "scenes": orange_scenes},
		{"name": "Banana", "enabled": banana_enabled, "scenes": banana_scenes},
		{"name": "DragonFruit", "enabled": dragon_fruit_enabled, "scenes": dragon_fruit_scenes},
		{"name": "Book", "enabled": book_enabled, "scenes": book_scenes},
		{"name": "Unknown", "enabled": unknown_enabled, "scenes": unknown_scenes}
	]

	# 过滤掉未启用或没有场景的类别
	var available = []
	for cls in classes:
		if cls.enabled and not cls.scenes.is_empty():
			available.append(cls)
	return available


# 使用网格方式放置物品
func place_items_on_grid(table_size: Vector2, available_classes: Array):
	var cell_size = min_distance_between_items
	# 预留边距，物品在缩小后的可用区域内摆放，避免贴边掉落
	var half_width = max(cell_size * 0.5, table_size.x - edge_margin)  # 桌子X方向半长
	var half_depth = max(cell_size * 0.5, table_size.y - edge_margin)  # 桌子Z方向半宽

	# 计算网格行列数
	var cols = max(1, int(floor(half_width * 2 / cell_size)))
	var rows = max(1, int(floor(half_depth * 2 / cell_size)))

	# 创建所有格子的坐标列表
	var grid_cells = []
	for r in range(rows):
		for c in range(cols):
			grid_cells.append(Vector2i(c, r))

	# 随机打乱格子顺序
	grid_cells.shuffle()

	# 从范围内随机选择物品数量
	var min_count = max(1, item_count_range.x)
	var max_count = item_count_range.y
	var target_count = randi() % (max_count - min_count + 1) + min_count
	
	# 实际可放置的最大数量（受限于格子数量）
	var max_items = min(target_count, grid_cells.size())
	var placed_count = 0

	for i in range(max_items):
		var cell = grid_cells[i]
		var c = cell.x
		var r = cell.y

		# 计算格子中心在桌子局部坐标系中的位置
		var x = -half_width + (c + 0.5) * cell_size
		var z = -half_depth + (r + 0.5) * cell_size

		# 在格子内加一点随机偏移（避免完全对齐）
		var jitter = cell_size * 0.4
		x += randf_range(-jitter, jitter)
		z += randf_range(-jitter, jitter)

		var position = Vector3(x, y_offset, z)

		# 随机选择一个可用类别
		var selected_class = available_classes[randi() % available_classes.size()]
		# 从选中类别中随机选择一个物品场景
		var item_scene = selected_class.scenes[randi() % selected_class.scenes.size()]
		
		# 实例化物品
		var item = item_scene.instantiate()
		objects_parent.add_child(item)

		# 设置位置和旋转
		item.global_position = table_mesh.global_position + position
		if random_tilt_enabled:
			# 完整的随机三轴姿态：先随机朝向(Y)，再在X/Z上随机倾斜/翻滚
			var tilt := deg_to_rad(max_tilt_degrees)
			item.global_rotation = Vector3(
				randf_range(-tilt, tilt),
				randf_range(0, PI * 2),
				randf_range(-tilt, tilt)
			)
		else:
			item.global_rotation = Vector3(0, randf_range(0, PI * 2), 0)

		# 设置随机缩放
		var scale_value = randf_range(scale_range.x, scale_range.y)
		item.scale = Vector3(scale_value, scale_value, scale_value)

		# 挂载脚本并设置classes属性
		item.set_script(item_script)
		item.classes = class_mapping[selected_class.name]

		placed_count += 1

	print("成功放置 ", placed_count, " 个物品")
	
func _on_complete_rotation(rotation):
	for obj in objects_parent.get_children():
		obj.queue_free()
	
	# 重新获取可用类别（可能有变动）
	available_classes = get_available_classes()
	
	if enable and not available_classes.is_empty():
		place_items_on_grid(table_size, available_classes)
