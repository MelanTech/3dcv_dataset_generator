extends Node

@export var camera: Camera3D

func _ready() -> void:
	camera.rotation_complete.connect(show_random_scene)
	show_random_scene(0)

func show_random_scene(rotation) -> void:
	# 获取所有子节点
	var children = get_children()
	
	# 如果没有子节点，直接返回
	if children.is_empty():
		print("没有场景可以显示")
		return
	
	# 随机选择一个子节点的索引
	var random_index = randi() % children.size()
	
	# 遍历所有子节点，设置可见性
	for i in range(children.size()):
		var child = children[i]
		# 检查节点是否有visible属性
		if "visible" in child:
			child.visible = (i == random_index)
		else:
			print("节点 %s 没有visible属性，无法设置可见性" % child.name)
