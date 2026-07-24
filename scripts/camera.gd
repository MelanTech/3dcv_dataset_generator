extends Camera3D

# 信号定义：每完成一圈自动旋转时发出
signal rotation_complete(rotations)

# 要面向的目标Marker3D
@export var target_marker: Node3D

# 朝向偏移量（欧拉角，单位：度）
@export var rotation_offset: Vector3 = Vector3.ZERO

# 相机到目标的水平距离
@export var distance: float = 5.0

# 相机高度（相对于目标）
@export var height: float = 2.0

# 旋转角度（度）- 水平方向
@export var rotation_angle: float = 0.0

# 已完成的旋转圈数
var completed_rotations: int = 0

# 上一帧的旋转角度，用于计算旋转增量
var previous_rotation_angle: float = 0.0

# 是否自动旋转
@export var auto_rotate: bool = false

# 自动旋转速度（度/秒）
@export var rotation_speed: float = 30.0

# 是否在启动时立即面向目标
@export var look_at_on_start: bool = true

# 随机过渡相关设置
@export var enable_random_transitions: bool = true  # 是否启用随机过渡
@export var transition_duration: float = 2.0  # 过渡动画持续时间（秒）

# 距离随机范围
@export var distance_range: Vector2 = Vector2(3.0, 7.0)  # x:最小值, y:最大值

# 高度随机范围
@export var height_range: Vector2 = Vector2(1.0, 3.0)  # x:最小值, y:最大值

# 旋转偏移随机范围 - X轴
@export var rotation_x_range: Vector2 = Vector2(-10.0, 10.0)  # x:最小值, y:最大值
# 旋转偏移随机范围 - Y轴
@export var rotation_y_range: Vector2 = Vector2(-10.0, 10.0)  # x:最小值, y:最大值
# 旋转偏移随机范围 - Z轴
@export var rotation_z_range: Vector2 = Vector2(-5.0, 5.0)  # x:最小值, y:最大值

# 过渡状态变量
var is_transitioning: bool = false
var transition_timer: float = 0.0

# 目标值
var target_distance: float = distance
var target_height: float = height
var target_rotation_offset: Vector3 = rotation_offset

# 起始值
var start_distance: float = distance
var start_height: float = height
var start_rotation_offset: Vector3 = rotation_offset

func _ready():
	if look_at_on_start and is_instance_valid(target_marker):
		update_camera_position_and_rotation()
	
	# 初始化角度跟踪变量
	previous_rotation_angle = rotation_angle
	
	# 初始化目标值并立即开始第一个过渡
	target_distance = distance
	target_height = height
	target_rotation_offset = rotation_offset
	
	# 启动时立即开始过渡
	if enable_random_transitions:
		start_new_transition()

func _process(delta):
	if not is_instance_valid(target_marker):
		return
	
	# 保存当前角度用于后续比较
	var old_angle = rotation_angle
	
	# 处理自动旋转
	if auto_rotate:
		# 使用fmod()处理浮点数取模运算
		rotation_angle = fmod(rotation_angle + rotation_speed * delta, 360.0)
		# 确保角度为正值
		if rotation_angle < 0:
			rotation_angle += 360.0
		
		# 检查是否完成了一圈（360度）
		check_rotation_complete(old_angle, rotation_angle)
	
	# 处理随机过渡 - 无停顿连续过渡
	if enable_random_transitions:
		if is_transitioning:
			# 正在过渡中，更新过渡进度
			transition_timer += delta
			var progress = transition_timer / transition_duration
			
			# 插值计算当前值
			distance = lerp(start_distance, target_distance, progress)
			height = lerp(start_height, target_height, progress)
			rotation_offset = start_rotation_offset.lerp(target_rotation_offset, progress)
			
			# 过渡即将结束时准备下一个过渡
			if progress >= 1.0:
				is_transitioning = false
				# 立即开始下一个过渡，实现无停顿效果
				start_new_transition()
	
	update_camera_position_and_rotation()

func check_rotation_complete(old_angle: float, new_angle: float):
	# 处理角度环绕的情况（例如从350度到10度，实际旋转了20度）
	if old_angle > new_angle + 180:  # 跨越了0度界限
		var rotation_increment = (360 - old_angle) + new_angle
		if rotation_increment > 0:
			# 计算完成的圈数（可能超过一圈，如果旋转速度极快）
			var full_rotations = floor(rotation_increment / 360)
			if full_rotations > 0:
				completed_rotations += full_rotations
				rotation_complete.emit(completed_rotations)
			# 检查是否刚好完成一圈
			elif (old_angle + rotation_increment) >= 360:
				completed_rotations += 1
				rotation_complete.emit(completed_rotations)

func update_camera_position_and_rotation():
	if not is_instance_valid(target_marker):
		return
	
	# 获取目标位置
	var target_position = target_marker.global_position
	
	# 将角度转换为弧度
	var rad_angle = rotation_angle * PI / 180.0
	
	# 计算相机水平位置（围绕目标旋转）
	var camera_x = sin(rad_angle) * distance
	var camera_z = cos(rad_angle) * distance
	
	# 设置相机位置（在目标位置基础上偏移：水平位置+高度）
	global_position = target_position + Vector3(camera_x, height, camera_z)
	
	# 让相机面向目标
	look_at(target_position, Vector3.UP)
	
	# 应用偏移旋转
	global_rotation = global_rotation + rotation_offset * PI / 180  # 转换为弧度

func start_new_transition():
	# 记录当前值作为过渡的起始值（使用当前实际值而非目标值，确保平滑过渡）
	start_distance = distance
	start_height = height
	start_rotation_offset = rotation_offset
	
	# 生成新的随机目标值
	target_distance = randf_range(distance_range.x, distance_range.y)
	target_height = randf_range(height_range.x, height_range.y)
	target_rotation_offset = Vector3(
		randf_range(rotation_x_range.x, rotation_x_range.y),
		randf_range(rotation_y_range.x, rotation_y_range.y),
		randf_range(rotation_z_range.x, rotation_z_range.y)
	)
	
	# 开始过渡
	is_transitioning = true
	transition_timer = 0.0

# 手动触发一次随机过渡
func trigger_transition():
	start_new_transition()
