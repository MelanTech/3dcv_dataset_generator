extends Camera3D

# 要复制其变换与投影参数的目标相机（主相机）
@export var target: Camera3D

func _process(_delta: float) -> void:
	if not target:
		print("请指定目标相机")
		return
	# 复制位姿
	global_transform = target.global_transform
	# 复制投影参数，保证深度图与 RGB 在空间上严格对齐。
	# 注意：不同步 near/far —— 它们只影响深度值到 [0,1] 缓冲的映射，
	# 不影响 X/Y 像素位置（已实测偏差为 0）。深度相机保留自己更紧的
	# near/far，让深度缓冲精度集中在场景区间，避免量化台阶。
	projection = target.projection
	fov = target.fov
	keep_aspect = target.keep_aspect
	size = target.size
