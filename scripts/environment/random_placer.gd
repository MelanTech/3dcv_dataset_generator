extends Node

@export var enable: bool = true

# 桌子的MeshInstance3D引用
@export var table_mesh: MeshInstance3D

# 物品要放置到的目标节点（如场景中的 Objects 容器）
@export var objects_parent: Node

@export var camera: Camera3D

# 物品类别启用状态
@export_category("Items")

# —— 正式类别启用开关 ——
@export_group("Official Enable")
@export var brush_enabled: bool = true
@export var earphone_enabled: bool = true
@export var cup_enabled: bool = true
@export var hanger_enabled: bool = true
@export var chocolate_enabled: bool = true
@export var sunflower_seeds_enabled: bool = true
@export var sausage_enabled: bool = true
@export var chips_enabled: bool = true
@export var canned_chips_enabled: bool = true
@export var can_enabled: bool = true
@export var bottle_enabled: bool = true
@export var milk_enabled: bool = true
@export var water_enabled: bool = true
@export var peach_enabled: bool = true
@export var apple_enabled: bool = true
@export var banana_enabled: bool = true
@export var pear_enabled: bool = true
@export var book_enabled: bool = true

# —— 正式类别场景列表 ——
@export_group("Official Scenes")
@export var brush_scenes: Array[PackedScene] = []
@export var earphone_scenes: Array[PackedScene] = []
@export var cup_scenes: Array[PackedScene] = []
@export var hanger_scenes: Array[PackedScene] = []
@export var chocolate_scenes: Array[PackedScene] = []
@export var sunflower_seeds_scenes: Array[PackedScene] = []
@export var sausage_scenes: Array[PackedScene] = []
@export var chips_scenes: Array[PackedScene] = []
@export var canned_chips_scenes: Array[PackedScene] = []
@export var can_scenes: Array[PackedScene] = []
@export var bottle_scenes: Array[PackedScene] = []
@export var milk_scenes: Array[PackedScene] = []
@export var water_scenes: Array[PackedScene] = []
@export var peach_scenes: Array[PackedScene] = []
@export var apple_scenes: Array[PackedScene] = []
@export var banana_scenes: Array[PackedScene] = []
@export var pear_scenes: Array[PackedScene] = []
@export var book_scenes: Array[PackedScene] = []

# —— Unknown 大类下的子类别启用开关（可单独管理，标签统一为 Unknown）——
@export_group("Unknown Enable")
@export var comb_enabled: bool = true
@export var biscuit_enabled: bool = true
@export var dragon_fruit_enabled: bool = true
@export var orange_enabled: bool = true
@export var pomegranate_enabled: bool = true
@export var jelly_enabled: bool = true

# —— Unknown 大类下的子类别场景列表 ——
@export_group("Unknown Scenes")
@export var comb_scenes: Array[PackedScene] = []
@export var biscuit_scenes: Array[PackedScene] = []
@export var dragon_fruit_scenes: Array[PackedScene] = []
@export var orange_scenes: Array[PackedScene] = []
@export var pomegranate_scenes: Array[PackedScene] = []
@export var jelly_scenes: Array[PackedScene] = []

# —— 各类别采样概率权重（相对权重，越大越容易被抽到；0 = 不采样）——
# 每次放置物品时按权重从"已启用且有场景"的类别中加权随机选取。
@export_group("Official Weights")
@export_range(0.0, 10.0, 0.1) var brush_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var earphone_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var cup_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var hanger_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var chocolate_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var sunflower_seeds_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var sausage_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var chips_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var canned_chips_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var can_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var bottle_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var milk_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var water_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var peach_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var apple_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var banana_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var pear_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var book_weight: float = 1.0

@export_group("Unknown Weights")
@export_range(0.0, 10.0, 0.1) var comb_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var biscuit_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var dragon_fruit_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var orange_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var pomegranate_weight: float = 1.0
@export_range(0.0, 10.0, 0.1) var jelly_weight: float = 1.0

@export_group("")
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

@export_group("")

# 类别与classes值的映射关系
@onready var class_mapping = get_node("/root/ClassMap").class_mapping

var available_classes
var table_size

func _ready():
	camera.rotation_complete.connect(_on_complete_rotation)

	# 获取桌子尺寸
	table_size = get_table_size()
	if table_size == Vector2.ZERO:
		print("无法获取桌子尺寸")

	# 由 SessionController 控制何时开始摆放，_ready 不再自动放置


# 进入运行：清掉残留并摆一批
func begin() -> void:
	clear_items()
	# 桌子形状可能在 Idle 期间被切换，重新取一次尺寸
	table_size = get_table_size()
	available_classes = get_available_classes()
	if available_classes.is_empty():
		print("错误：所有类别中都没有添加启用的物品场景")
		return
	if table_size == Vector2.ZERO:
		print("无法获取桌子尺寸")
		return
	place_items_on_grid(table_size, available_classes)


# 停止运行：清空桌面
func halt() -> void:
	clear_items()


# 清空已放置的物品
func clear_items() -> void:
	for obj in objects_parent.get_children():
		obj.queue_free()


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
		# —— 正式类别 ——
		{"name": "Brush", "enabled": brush_enabled, "scenes": brush_scenes, "weight": brush_weight},
		{"name": "Earphone", "enabled": earphone_enabled, "scenes": earphone_scenes, "weight": earphone_weight},
		{"name": "Cup", "enabled": cup_enabled, "scenes": cup_scenes, "weight": cup_weight},
		{"name": "Hanger", "enabled": hanger_enabled, "scenes": hanger_scenes, "weight": hanger_weight},
		{"name": "Chocolate", "enabled": chocolate_enabled, "scenes": chocolate_scenes, "weight": chocolate_weight},
		{"name": "SunflowerSeeds", "enabled": sunflower_seeds_enabled, "scenes": sunflower_seeds_scenes, "weight": sunflower_seeds_weight},
		{"name": "Sausage", "enabled": sausage_enabled, "scenes": sausage_scenes, "weight": sausage_weight},
		{"name": "Chips", "enabled": chips_enabled, "scenes": chips_scenes, "weight": chips_weight},
		{"name": "CannedChips", "enabled": canned_chips_enabled, "scenes": canned_chips_scenes, "weight": canned_chips_weight},
		{"name": "Can", "enabled": can_enabled, "scenes": can_scenes, "weight": can_weight},
		{"name": "Bottle", "enabled": bottle_enabled, "scenes": bottle_scenes, "weight": bottle_weight},
		{"name": "Milk", "enabled": milk_enabled, "scenes": milk_scenes, "weight": milk_weight},
		{"name": "Water", "enabled": water_enabled, "scenes": water_scenes, "weight": water_weight},
		{"name": "Peach", "enabled": peach_enabled, "scenes": peach_scenes, "weight": peach_weight},
		{"name": "Apple", "enabled": apple_enabled, "scenes": apple_scenes, "weight": apple_weight},
		{"name": "Banana", "enabled": banana_enabled, "scenes": banana_scenes, "weight": banana_weight},
		{"name": "Pear", "enabled": pear_enabled, "scenes": pear_scenes, "weight": pear_weight},
		{"name": "Book", "enabled": book_enabled, "scenes": book_scenes, "weight": book_weight},
		# —— Unknown 大类下的子类别（标签统一映射到 Unknown）——
		{"name": "Comb", "enabled": comb_enabled, "scenes": comb_scenes, "weight": comb_weight},
		{"name": "Biscuit", "enabled": biscuit_enabled, "scenes": biscuit_scenes, "weight": biscuit_weight},
		{"name": "DragonFruit", "enabled": dragon_fruit_enabled, "scenes": dragon_fruit_scenes, "weight": dragon_fruit_weight},
		{"name": "Orange", "enabled": orange_enabled, "scenes": orange_scenes, "weight": orange_weight},
		{"name": "Pomegranate", "enabled": pomegranate_enabled, "scenes": pomegranate_scenes, "weight": pomegranate_weight},
		{"name": "Jelly", "enabled": jelly_enabled, "scenes": jelly_scenes, "weight": jelly_weight},
	]

	# 过滤掉未启用、没有场景、或权重<=0 的类别
	var available = []
	for cls in classes:
		if cls.enabled and not cls.scenes.is_empty() and cls.weight > 0.0:
			available.append(cls)
	return available


# 按权重从可用类别中加权随机选取一个类别
func pick_weighted_class(available_classes: Array) -> Dictionary:
	var total_weight = 0.0
	for cls in available_classes:
		total_weight += cls.weight
	# 权重总和异常时退化为均匀随机
	if total_weight <= 0.0:
		return available_classes[randi() % available_classes.size()]

	var roll = randf() * total_weight
	var acc = 0.0
	for cls in available_classes:
		acc += cls.weight
		if roll < acc:
			return cls
	return available_classes[available_classes.size() - 1]


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

		# 按采样权重随机选择一个可用类别
		var selected_class = pick_weighted_class(available_classes)
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
	# 相机待命时不响应（正常情况下 Idle 相机不会转、不会发信号，这里做防御）
	if not camera.active:
		return

	for obj in objects_parent.get_children():
		obj.queue_free()
	
	# 重新获取可用类别（可能有变动）
	available_classes = get_available_classes()
	
	if not available_classes.is_empty():
		place_items_on_grid(table_size, available_classes)
