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
	# near/far 也必须同步，否则 RGB 可见但超出深度相机 far plane 的墙体
	# 会在 depth texture 中变成 reversed-Z 背景值 0，最终被编码为黑色无效深度。
	projection = target.projection
	fov = target.fov
	keep_aspect = target.keep_aspect
	size = target.size
	near = target.near
	far = target.far
