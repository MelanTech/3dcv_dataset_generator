extends Light3D

# 目标Marker3D节点
@export var target_marker: Marker3D

# 旋转速度 (度/秒)
@export var rotation_speed: float = 30.0

# 随机高度范围
@export var height_range: Vector2 = Vector2(2.0, 5.0)

# 随机距离范围
@export var distance_range: Vector2 = Vector2(3.0, 8.0)

# 随机灯光强度范围
@export var energy_range: Vector2 = Vector2(0.5, 2.0)

# 颜色变化的时间间隔范围
@export var color_change_interval: Vector2 = Vector2(2.0, 5.0)

# 属性变化的时间间隔范围
@export var property_change_interval: Vector2 = Vector2(3.0, 7.0)

# 过渡时间（秒）
@export var transition_time: float = 1.0

# 内部计时器
var color_timer: float = 0.0
var property_timer: float = 0.0
var transition_progress: float = 1.0

# 下次变化时间
var next_color_change: float = 0.0
var next_property_change: float = 0.0

# 目标属性值（用于平滑过渡）
var target_position: Vector3
var target_energy: float
var target_color: Color

# 当前属性值
var current_position: Vector3
var current_energy: float
var current_color: Color

func _ready():
	if target_marker:
		# 初始化位置和属性
		current_position = global_position
		target_position = current_position
		current_energy = light_energy
		target_energy = current_energy
		current_color = light_color
		target_color = current_color
		
		randomize_target_properties()
		randomize_target_color()
		
		# 初始化下次变化时间
		next_color_change = randf_range(color_change_interval.x, color_change_interval.y)
		next_property_change = randf_range(property_change_interval.x, property_change_interval.y)
	else:
		print("警告: 请指定目标Marker3D")

func _process(delta: float):
	if not target_marker:
		return
	
	# 更新计时器
	color_timer += delta
	property_timer += delta
	
	# 检查是否需要改变颜色
	if color_timer >= next_color_change:
		randomize_target_color()
		color_timer = 0.0
		next_color_change = randf_range(color_change_interval.x, color_change_interval.y)
		transition_progress = 0.0
	
	# 检查是否需要改变属性
	if property_timer >= next_property_change:
		randomize_target_properties()
		property_timer = 0.0
		next_property_change = randf_range(property_change_interval.x, property_change_interval.y)
		transition_progress = 0.0
	
	# 更新过渡进度
	if transition_progress < 1.0:
		transition_progress += delta / transition_time
		transition_progress = min(transition_progress, 1.0)
		
		# 平滑过渡到目标属性
		global_position = current_position.lerp(target_position, transition_progress)
		light_energy = lerp(current_energy, target_energy, transition_progress)
		light_color = current_color.lerp(target_color, transition_progress)
	else:
		# 过渡完成，更新当前值
		current_position = target_position
		current_energy = target_energy
		current_color = target_color
	
	# 围绕目标旋转
	rotate_around_target(delta)
	
	# 始终指向目标
	look_at(target_marker.global_position, Vector3.UP)

func rotate_around_target(delta: float):
	# 获取相对于目标的位置
	var local_pos = global_position - target_marker.global_position
	
	# 计算旋转角度
	var rotation_amount = rotation_speed * delta
	
	# 绕Y轴旋转
	var rotated = local_pos.rotated(Vector3.UP, deg_to_rad(rotation_amount))
	
	# 更新位置（同时更新当前和目标位置，保持旋转平滑）
	global_position = target_marker.global_position + rotated
	current_position = global_position
	target_position = global_position

func randomize_target_properties():
	if not target_marker:
		return
	
	# 保存当前属性作为过渡起点
	current_position = global_position
	current_energy = light_energy
	
	# 随机高度
	var new_height = randf_range(height_range.x, height_range.y)
	
	# 随机距离
	var new_distance = randf_range(distance_range.x, distance_range.y)
	
	# 随机灯光强度
	target_energy = randf_range(energy_range.x, energy_range.y)
	
	# 计算新目标位置（在目标周围随机角度）
	var angle = randf_range(0, PI * 2)
	var x = cos(angle) * new_distance
	var z = sin(angle) * new_distance
	
	# 设置新目标位置
	target_position = Vector3(
		target_marker.global_position.x + x,
		target_marker.global_position.y + new_height,
		target_marker.global_position.z + z
	)

func randomize_target_color():
	# 保存当前颜色作为过渡起点
	current_color = light_color
	
	# 50%概率选择黄光范围，50%概率选择白光范围
	if randf() < 0.5:
		# 黄光范围 (Hue: 0.1 到 0.15)
		var hue = randf_range(0.1, 0.15)
		var saturation = randf_range(0.5, 1.0)
		var value = randf_range(0.8, 1.0)
		target_color = Color.from_hsv(hue, saturation, value)
	else:
		# 白光范围 (低饱和度)
		var hue = randf_range(0, 1)
		var saturation = randf_range(0, 0.3)
		var value = randf_range(0.8, 1.0)
		target_color = Color.from_hsv(hue, saturation, value)
	
