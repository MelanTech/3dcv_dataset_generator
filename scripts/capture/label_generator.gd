extends RefCounted
class_name LabelGenerator


static func get_all_labels(
	camera: Camera3D,
	table: Node3D,
	object_container: Node,
	unknown_class_id: int,
	ray_count: int,
	occlusion_threshold: int,
	world: World3D
) -> Array:
	var labels := []
	if camera == null or table == null or object_container == null:
		return labels

	for obj in object_container.get_children():
		if obj.classes == unknown_class_id:
			continue
		elif obj.position.y < 4.5:
			obj.queue_free()
			continue
		elif is_occluded_above_threshold(obj, camera, world, ray_count, occlusion_threshold):
			continue

		var bbox := get_2d_bbox(obj, camera)
		var cls = obj.classes
		labels.append({"bbox": bbox, "class": cls})

	labels.append(get_table_label(table, camera))
	return labels


static func get_table_label(table: Node3D, camera: Camera3D) -> Dictionary:
	return {
		"bbox": get_2d_bbox(table, camera),
		"class": table.classes,
	}


static func get_2d_bbox(node: Node3D, camera: Camera3D) -> Array:
	# 获取碰撞形状节点及其变换
	var collision_shape := node.get_child(1) as CollisionShape3D
	if collision_shape == null:
		print("找不到有效的 CollisionShape3D")
		return []

	var shape := collision_shape.shape
	var vertices := PackedVector3Array()
	var shape_transform := collision_shape.transform

	# 根据形状类型获取顶点
	if shape is ConvexPolygonShape3D:
		vertices = shape.get_points()
	elif shape is BoxShape3D:
		var half_extents: Vector3 = shape.size / 2.0
		var local_vertices := PackedVector3Array([
			Vector3(-half_extents.x, -half_extents.y, -half_extents.z),
			Vector3(half_extents.x, -half_extents.y, -half_extents.z),
			Vector3(half_extents.x, half_extents.y, -half_extents.z),
			Vector3(-half_extents.x, half_extents.y, -half_extents.z),
			Vector3(-half_extents.x, -half_extents.y, half_extents.z),
			Vector3(half_extents.x, -half_extents.y, half_extents.z),
			Vector3(half_extents.x, half_extents.y, half_extents.z),
			Vector3(-half_extents.x, half_extents.y, half_extents.z),
		])
		for vertex in local_vertices:
			vertices.append(shape_transform * vertex)

	var viewport_points := []
	for vertex in vertices:
		var world_vertex: Vector3 = node.global_transform * vertex
		viewport_points.append(camera.unproject_position(world_vertex))

	if viewport_points.is_empty():
		return []

	var min_x: float = viewport_points[0].x
	var max_x: float = viewport_points[0].x
	var min_y: float = viewport_points[0].y
	var max_y: float = viewport_points[0].y

	for point in viewport_points:
		min_x = min(min_x, point.x)
		max_x = max(max_x, point.x)
		min_y = min(min_y, point.y)
		max_y = max(max_y, point.y)

	return [min_x, min_y, max_x, max_y]


static func is_occluded_above_threshold(
	object: Node3D,
	camera: Camera3D,
	world: World3D,
	ray_count: int,
	occlusion_threshold: int
) -> bool:
	if camera == null or world == null:
		return false

	var mesh := object.get_child(0) as MeshInstance3D
	if mesh == null:
		return false
	var aabb: AABB = mesh.get_aabb()
	var points := get_detection_points(object, aabb, ray_count)

	var occluded_count := 0
	for point in points:
		if is_point_occluded(point, camera, world):
			occluded_count += 1

	var occlusion_percentage := (float(occluded_count) / float(points.size())) * 100.0
	return occlusion_percentage >= occlusion_threshold


static func get_detection_points(object: Node3D, aabb: AABB, ray_count: int) -> Array:
	var points := []
	var local_points := []
	var grid_size: float = ceil(sqrt(ray_count))
	var step: float = 1.0 / (grid_size - 1.0) if ray_count > 1 else 1.0

	for i in range(ray_count):
		var x: float = aabb.position.x + fmod(i, grid_size) * step * aabb.size.x
		var y: float = aabb.position.y + (i / floor(sqrt(ray_count))) * step * aabb.size.y
		var z: float = aabb.position.z + aabb.size.z * 0.5
		local_points.append(Vector3(x, y, z))

	var global_center := object.global_position
	points.append(global_center)

	for local_point in local_points:
		var global_point: Vector3 = object.to_global(local_point)
		if global_point.distance_to(global_center) > 0.01 and global_point not in points:
			points.append(global_point)

	return points.slice(0, ray_count)


static func is_point_occluded(point: Vector3, camera: Camera3D, world: World3D) -> bool:
	var ray_start := camera.global_position
	var ray_end := point
	var total_distance := ray_start.distance_to(ray_end)

	if total_distance < 0.001:
		return false

	var space_state := world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	var result := space_state.intersect_ray(query)

	if result:
		var hit_distance: float = ray_start.distance_to(result.position)
		return hit_distance < total_distance - 0.1

	return false
