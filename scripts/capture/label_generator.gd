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
	var vertices := get_collision_shape_world_vertices(node)
	if vertices.is_empty():
		vertices = get_mesh_aabb_world_vertices(node)

	var viewport_points := []
	for vertex in vertices:
		viewport_points.append(camera.unproject_position(vertex))

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

	var mesh := find_mesh_instance(object)
	if mesh == null:
		return false
	var aabb: AABB = mesh.get_aabb()
	var points := get_detection_points(mesh, aabb, ray_count)
	if points.is_empty():
		return false

	var occluded_count := 0
	for point in points:
		if is_point_occluded(point, camera, world):
			occluded_count += 1

	var occlusion_percentage := (float(occluded_count) / float(points.size())) * 100.0
	return occlusion_percentage >= occlusion_threshold


static func get_detection_points(mesh: MeshInstance3D, aabb: AABB, ray_count: int) -> Array:
	var points := []
	if ray_count <= 0:
		return points

	var local_points := []
	var grid_size: int = max(1, int(ceil(sqrt(float(ray_count)))))
	var step: float = 1.0 / float(grid_size - 1) if grid_size > 1 else 1.0

	for i in range(ray_count):
		var col := i % grid_size
		var row := i / grid_size
		var x: float = aabb.position.x + float(col) * step * aabb.size.x
		var y: float = aabb.position.y + float(row) * step * aabb.size.y
		var z: float = aabb.position.z + aabb.size.z * 0.5
		local_points.append(Vector3(x, y, z))

	var global_center: Vector3 = mesh.global_transform * (aabb.position + aabb.size * 0.5)
	points.append(global_center)

	for local_point in local_points:
		var global_point: Vector3 = mesh.global_transform * local_point
		if global_point.distance_to(global_center) > 0.01 and global_point not in points:
			points.append(global_point)

	return points.slice(0, ray_count)


static func find_collision_shape(node: Node) -> CollisionShape3D:
	if node is CollisionShape3D:
		var collision_shape := node as CollisionShape3D
		if collision_shape.shape != null and not collision_shape.disabled:
			return collision_shape

	for child in node.get_children():
		var found := find_collision_shape(child)
		if found != null:
			return found
	return null


static func find_mesh_instance(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			return mesh_instance

	for child in node.get_children():
		var found := find_mesh_instance(child)
		if found != null:
			return found
	return null


static func get_collision_shape_world_vertices(node: Node3D) -> PackedVector3Array:
	var collision_shape := find_collision_shape(node)
	var vertices := PackedVector3Array()
	if collision_shape == null:
		return vertices

	var shape := collision_shape.shape
	if shape is ConvexPolygonShape3D:
		for point in shape.get_points():
			vertices.append(collision_shape.global_transform * point)
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
			vertices.append(collision_shape.global_transform * vertex)

	return vertices


static func get_mesh_aabb_world_vertices(node: Node3D) -> PackedVector3Array:
	var mesh := find_mesh_instance(node)
	var vertices := PackedVector3Array()
	if mesh == null:
		print("找不到有效的 CollisionShape3D 或 MeshInstance3D: ", node.name)
		return vertices

	var aabb := mesh.get_aabb()
	var min_corner := aabb.position
	var max_corner := aabb.position + aabb.size
	var local_vertices := PackedVector3Array([
		Vector3(min_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, max_corner.y, max_corner.z),
		Vector3(min_corner.x, max_corner.y, max_corner.z),
	])
	for vertex in local_vertices:
		vertices.append(mesh.global_transform * vertex)

	return vertices


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
