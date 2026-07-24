extends MeshInstance3D

# 过渡时间（秒）
@export var transition_time: float = 2.0

# 最小颜色亮度（0-1）
@export var min_brightness: float = 0.5

# 最大颜色亮度（0-1）
@export var max_brightness: float = 1.0

# 颜色差异限制（0-1，值越小差异越小，过渡越平滑）
@export var color_variation_limit: float = 0.5

# 当前颜色
var current_color: Color

# 目标颜色
var target_color: Color

# 过渡计时器
var transition_timer: float = 0.0

func _ready():
	if not material_override:
		material_override = StandardMaterial3D.new()
	
	current_color = generate_random_color()
	target_color = generate_related_color(current_color)  # 基于当前颜色生成关联目标色
	update_material_color(current_color)

func _process(delta: float):
	transition_timer += delta
	var progress: float = transition_timer / transition_time
	
	if progress >= 1.0:
		# 过渡结束时，平滑衔接：用当前终点作为新起点，生成关联的新目标
		current_color = target_color
		target_color = generate_related_color(current_color)  # 基于当前颜色生成新目标
		transition_timer = 0.0
		progress = 0.0
	
	# 线性插值过渡（内置lerp已做平滑处理）
	var new_color: Color = current_color.lerp(target_color, progress)
	update_material_color(new_color)

# 生成与当前颜色有一定关联的新颜色（减少突变）
func generate_related_color(base_color: Color) -> Color:
	if randf() < 0.1:  # 10% 的概率直接生成白色
		return Color(1, 1, 1)
	
	# 在基础颜色附近随机微调，限制差异范围
	var r = clamp(base_color.r + randf_range(-color_variation_limit, color_variation_limit), 0.0, 1.0)
	var g = clamp(base_color.g + randf_range(-color_variation_limit, color_variation_limit), 0.0, 1.0)
	var b = clamp(base_color.b + randf_range(-color_variation_limit, color_variation_limit), 0.0, 1.0)
	
	var color = Color(r, g, b)
	var target_brightness = randf_range(min_brightness, max_brightness)
	
	# 使用更准确的亮度计算（ luminance 公式，接近人眼感知）
	var current_luminance = 0.299 * color.r + 0.587 * color.g + 0.114 * color.b
	if current_luminance < 0.001:
		return Color(target_brightness, target_brightness, target_brightness)
	
	# 调整到目标亮度，严格限制在0-1
	var scale = target_brightness / current_luminance
	color.r = clamp(color.r * scale, 0.0, 1.0)
	color.g = clamp(color.g * scale, 0.0, 1.0)
	color.b = clamp(color.b * scale, 0.0, 1.0)
	
	return color

# 兼容完全随机颜色（如需偶尔大变化，可调用此函数）
func generate_random_color() -> Color:
	return generate_related_color(Color(randf(), randf(), randf()))

func update_material_color(color: Color):
	if material_override is StandardMaterial3D:
		material_override.albedo_color = color
