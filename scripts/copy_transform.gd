extends Node3D

# 要复制其transform的目标物体
@export var target: Node3D

func _process(delta: float) -> void:
	# 检查目标是否存在
	if target:
		# 复制位置
		global_position = target.global_position
		# 复制旋转
		global_rotation = target.global_rotation
	else:
		print("请指定目标物体")
	
