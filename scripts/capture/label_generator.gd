extends RefCounted
class_name LabelGenerator

enum OcclusionSampleMode {
	GRID,
	BOUNDS_KEY_POINTS,
	HYBRID,
}


static func get_all_labels(
	camera: Camera3D,
	table: Node3D,
	object_container: Node,
	unknown_class_id: int,
	world: World3D,
	visibility_threshold: int = 20,
	occlusion_sample_mode: int = OcclusionSampleMode.BOUNDS_KEY_POINTS,
	occlusion_grid_sample_count: int = 10,
	debug_occlusion: bool = false,
	drop_below_table_threshold: float = 0.35
) -> Array:
	var labels := []
	if camera == null or object_container == null:
		return labels

	var has_table := table != null
	var table_top_y := get_node_top_y(table) if has_table else 0.0
	for obj in object_container.get_children():
		if obj.classes == unknown_class_id:
			continue
		elif has_table and is_dropped_below_table(obj, table_top_y, drop_below_table_threshold):
			obj.queue_free()
			continue
		elif is_visibility_below_threshold(
			obj,
			camera,
			world,
			visibility_threshold,
			occlusion_sample_mode,
			occlusion_grid_sample_count,
			debug_occlusion
		):
			continue

		var bbox := get_2d_bbox(obj, camera)
		var cls = obj.classes
		labels.append({"bbox": bbox, "class": cls})

	if has_table:
		labels.append(get_table_label(table, camera))
	return labels



static func is_dropped_below_table(object: Node3D, table_top_y: float, threshold: float) -> bool:
	var object_bottom_y := get_node_bottom_y(object)
	return object_bottom_y < table_top_y - threshold


static func get_node_bottom_y(node: Node3D) -> float:
	var bounds := get_node_world_bounds(node)
	if bounds.size == Vector3.ZERO:
		return node.global_position.y
	return bounds.position.y


static func get_node_top_y(node: Node3D) -> float:
	var bounds := get_node_world_bounds(node)
	if bounds.size == Vector3.ZERO:
		return node.global_position.y
	return bounds.position.y + bounds.size.y


static func get_node_world_bounds(node: Node3D) -> AABB:
	var vertices := get_collision_shape_world_vertices(node)
	if vertices.is_empty():
		vertices = get_mesh_aabb_world_vertices(node)
	if vertices.is_empty():
		return AABB(node.global_position, Vector3.ZERO)

	var min_corner := vertices[0]
	var max_corner := vertices[0]
	for vertex in vertices:
		min_corner.x = min(min_corner.x, vertex.x)
		min_corner.y = min(min_corner.y, vertex.y)
		min_corner.z = min(min_corner.z, vertex.z)
		max_corner.x = max(max_corner.x, vertex.x)
		max_corner.y = max(max_corner.y, vertex.y)
		max_corner.z = max(max_corner.z, vertex.z)
	return AABB(min_corner, max_corner - min_corner)

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


static func is_visibility_below_threshold(
	object: Node3D,
	camera: Camera3D,
	world: World3D,
	visibility_threshold: int = 20,
	occlusion_sample_mode: int = OcclusionSampleMode.BOUNDS_KEY_POINTS,
	occlusion_grid_sample_count: int = 10,
	debug_occlusion: bool = false
) -> bool:
	if camera == null or world == null:
		return false

	var mesh := find_mesh_instance(object)
	if mesh == null:
		return false
	var aabb: AABB = mesh.get_aabb()
	var points := get_detection_points(mesh, aabb, occlusion_grid_sample_count, occlusion_sample_mode)
	points = filter_screen_points(points, camera)
	if points.is_empty():
		return false

	var exclude_rids := get_collision_object_rids(object)
	var occluded_count := 0
	for point in points:
		if is_point_occluded(point, camera, world, exclude_rids):
			occluded_count += 1

	var visible_count := points.size() - occluded_count
	var visible_percentage := (float(visible_count) / float(points.size())) * 100.0
	var should_drop := visible_percentage <= visibility_threshold
	if debug_occlusion:
		var occlusion_percentage := (float(occluded_count) / float(points.size())) * 100.0
		print("[occlusion] %s visible=%d/%d (%.1f%%) occluded=%.1f%% drop=%s" % [
			object.name,
			visible_count,
			points.size(),
			visible_percentage,
			occlusion_percentage,
			str(should_drop),
		])
	return should_drop


static func get_detection_points(
	mesh: MeshInstance3D,
	aabb: AABB,
	grid_sample_count: int,
	occlusion_sample_mode: int = OcclusionSampleMode.BOUNDS_KEY_POINTS
) -> Array:
	match occlusion_sample_mode:
		OcclusionSampleMode.GRID:
			return get_grid_detection_points(mesh, aabb, grid_sample_count)
		OcclusionSampleMode.HYBRID:
			return _deduplicate_points(
				get_bounds_key_points(mesh, aabb) + get_grid_detection_points(mesh, aabb, grid_sample_count)
			)
		_:
			return get_bounds_key_points(mesh, aabb)


static func get_grid_detection_points(mesh: MeshInstance3D, aabb: AABB, grid_sample_count: int) -> Array:
	var points := []
	if grid_sample_count <= 0:
		return points

	var local_points := []
	var grid_size: int = max(1, int(ceil(sqrt(float(grid_sample_count)))))
	var step: float = 1.0 / float(grid_size - 1) if grid_size > 1 else 1.0

	for i in range(grid_sample_count):
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

	return points.slice(0, grid_sample_count)


static func get_bounds_key_points(mesh: MeshInstance3D, aabb: AABB) -> Array:
	var points := []
	var min_corner := aabb.position
	var max_corner := aabb.position + aabb.size
	var center := aabb.position + aabb.size * 0.5
	var local_points := [
		center,
		# 8 corners
		Vector3(min_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, max_corner.y, max_corner.z),
		Vector3(min_corner.x, max_corner.y, max_corner.z),
		# 6 face centers
		Vector3(min_corner.x, center.y, center.z),
		Vector3(max_corner.x, center.y, center.z),
		Vector3(center.x, min_corner.y, center.z),
		Vector3(center.x, max_corner.y, center.z),
		Vector3(center.x, center.y, min_corner.z),
		Vector3(center.x, center.y, max_corner.z),
	]
	for local_point in local_points:
		points.append(mesh.global_transform * local_point)
	return points


static func _deduplicate_points(points: Array) -> Array:
	var result := []
	for point in points:
		var duplicate := false
		for existing in result:
			if point.distance_to(existing) <= 0.01:
				duplicate = true
				break
		if not duplicate:
			result.append(point)
	return result


static func filter_screen_points(points: Array, camera: Camera3D) -> Array:
	var result := []
	var viewport := camera.get_viewport()
	if viewport == null:
		return points
	var viewport_size := viewport.get_visible_rect().size
	for point in points:
		if camera.is_position_behind(point):
			continue
		var screen_point := camera.unproject_position(point)
		if screen_point.x < 0.0 or screen_point.y < 0.0:
			continue
		if screen_point.x > viewport_size.x or screen_point.y > viewport_size.y:
			continue
		result.append(point)
	return result


static func get_collision_object_rids(node: Node) -> Array[RID]:
	var result: Array[RID] = []
	if node is CollisionObject3D:
		result.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		result.append_array(get_collision_object_rids(child))
	return result


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


static func is_point_occluded(point: Vector3, camera: Camera3D, world: World3D, exclude_rids: Array[RID]) -> bool:
	var ray_start := camera.global_position
	var ray_end := point
	var total_distance := ray_start.distance_to(ray_end)

	if total_distance < 0.001:
		return false

	var space_state := world.direct_space_state
	var query := PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.exclude = exclude_rids
	var result := space_state.intersect_ray(query)

	if result:
		var hit_distance: float = ray_start.distance_to(result.position)
		return hit_distance < total_distance - 0.1

	return false
