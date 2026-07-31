extends Node

@export var object_catalog: ObjectCatalog
@export var table_mesh: MeshInstance3D
@export var distractor_parent: Node3D
@export var camera: Node

@export_category("Placement")
@export var enabled: bool = true
@export var distractor_count_range: Vector2i = Vector2i(3, 7)
@export var edge_margin: float = 0.6
@export_range(0.0, 1.0, 0.05) var alpha: float = 0.92
@export var surface_offset: float = 0.04
@export var layer_offset: float = 0.003
@export var scale_range: Vector2 = Vector2(0.8, 1.15)
@export var placement_attempts_per_distractor: int = 40
@export var overlap_padding: float = 0.08

@export_category("Sprite Rendering")
@export var render_size: Vector2i = Vector2i(256, 256)
@export var render_padding: float = 1.25
@export var max_cached_sprites: int = 64
@export var cache_sprites: bool = false
@export var random_view_enabled: bool = true
@export var view_elevation_degrees_range: Vector2 = Vector2(25.0, 70.0)
@export var min_distractor_size: float = 0.55
@export var max_distractor_size: float = 1.8

var _sprite_cache: Dictionary = {}
var _render_viewport: SubViewport
var _render_root: Node3D
var _render_camera: Camera3D
var _generation_id: int = 0
var _running: bool = false


func _ready() -> void:
	_setup_sprite_renderer()
	if camera != null and camera.has_signal("rotation_complete"):
		camera.rotation_complete.connect(_on_complete_rotation)


func begin() -> void:
	_running = true
	_generation_id += 1
	if not enabled:
		clear_distractors()
		return
	if object_catalog == null or table_mesh == null or distractor_parent == null:
		return
	call_deferred("_place_distractors_async", _generation_id)


func halt() -> void:
	_running = false
	_generation_id += 1
	clear_distractors()


func clear_distractors() -> void:
	if distractor_parent == null:
		return
	for child in distractor_parent.get_children():
		child.queue_free()


func _place_distractors_async(generation_id: int) -> void:
	var categories := object_catalog.get_available_categories()
	if categories.is_empty():
		return

	var table_half_size := get_table_size()
	if table_half_size == Vector2.ZERO:
		return

	var min_count: int = max(0, distractor_count_range.x)
	var max_count: int = max(min_count, distractor_count_range.y)
	var target_count: int = randi() % (max_count - min_count + 1) + min_count
	var table_top_y := get_table_top_y()
	var pending_distractors: Array[Dictionary] = []
	var occupied_rects: Array[Rect2] = []

	for i in range(target_count):
		if generation_id != _generation_id or not _running:
			return

		var category: ObjectCategory = pick_weighted_category(categories)
		var item_scene: PackedScene = category.scenes[randi() % category.scenes.size()]
		var sprite_info: Dictionary = await _get_or_render_sprite(item_scene)
		if sprite_info.is_empty():
			continue

		var texture := sprite_info["texture"] as Texture2D
		var footprint := sprite_info["footprint"] as Vector2
		var scale_value := randf_range(scale_range.x, scale_range.y)
		var world_size := footprint * scale_value
		var reserved_size := _get_reserved_size(world_size)
		var placement := _pick_non_overlapping_table_position(table_half_size, reserved_size, occupied_rects)
		if placement.is_empty():
			continue

		var world_xz := placement["position"] as Vector2
		occupied_rects.append(placement["rect"] as Rect2)
		pending_distractors.append({
			"texture": texture,
			"world_size": world_size,
			"position": Vector3(world_xz.x, table_top_y + surface_offset + float(i) * layer_offset, world_xz.y),
		})

	if generation_id != _generation_id or not _running:
		return

	clear_distractors()
	for distractor in pending_distractors:
		_add_distractor_plane(
			distractor["texture"] as Texture2D,
			distractor["world_size"] as Vector2,
			distractor["position"] as Vector3
		)

	print("成功放置 ", pending_distractors.size(), " 个桌面贴图干扰项，桌面高度 ", table_top_y)


func _get_or_render_sprite(item_scene: PackedScene) -> Dictionary:
	var cache_key := item_scene.resource_path
	if cache_sprites and _sprite_cache.has(cache_key):
		return _sprite_cache[cache_key]

	var sprite_info: Dictionary = await _render_prefab_sprite(item_scene)
	if sprite_info.is_empty():
		return {}

	if not cache_sprites:
		return sprite_info

	if _sprite_cache.size() >= max_cached_sprites:
		_sprite_cache.clear()
	_sprite_cache[cache_key] = sprite_info
	return sprite_info


func _render_prefab_sprite(item_scene: PackedScene) -> Dictionary:
	_setup_sprite_renderer()
	_clear_render_root()

	var item := item_scene.instantiate() as Node3D
	if item == null:
		return {}

	_render_root.add_child(item)
	_freeze_bodies(item)
	await get_tree().process_frame

	var bounds := get_node_world_bounds(item)
	if bounds.size == Vector3.ZERO:
		_clear_render_root()
		return {}

	var bounds_center := bounds.position + bounds.size * 0.5
	item.global_position -= bounds_center
	await get_tree().process_frame

	var visual_size := _calculate_visual_size(bounds.size)
	var render_extent: float = max(visual_size, 0.5) * render_padding
	_render_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_render_camera.size = max(render_extent, 0.5)
	_position_sprite_camera(render_extent)
	_render_camera.current = true

	_render_viewport.size = render_size
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await get_tree().process_frame
	await get_tree().process_frame

	if DisplayServer.get_name() == "headless":
		_clear_render_root()
		return {}

	var viewport_texture := _render_viewport.get_texture()
	if viewport_texture == null:
		_clear_render_root()
		return {}

	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		_clear_render_root()
		return {}

	image.convert(Image.FORMAT_RGBA8)
	var cropped_image := _crop_to_alpha_bounds(image)
	var footprint := _calculate_sprite_footprint(cropped_image.get_size(), visual_size)
	var texture := ImageTexture.create_from_image(cropped_image)
	_clear_render_root()
	return {
		"texture": texture,
		"footprint": footprint,
	}


func _calculate_visual_size(bounds_size: Vector3) -> float:
	var largest_axis: float = max(bounds_size.x, max(bounds_size.y, bounds_size.z))
	return clamp(largest_axis, min_distractor_size, max_distractor_size)


func _calculate_sprite_footprint(image_size: Vector2i, visual_size: float) -> Vector2:
	var width_source := float(image_size.x)
	var height_source := float(image_size.y)
	var max_source: float = max(width_source, height_source)
	if max_source <= 1.0:
		return Vector2(visual_size, visual_size)

	var aspect := Vector2(width_source / max_source, height_source / max_source)
	aspect.x = max(aspect.x, 0.35)
	aspect.y = max(aspect.y, 0.35)
	return Vector2(visual_size * aspect.x, visual_size * aspect.y)


func _position_sprite_camera(render_extent: float) -> void:
	if not random_view_enabled:
		_render_camera.global_position = Vector3(0.0, max(render_extent, 2.0), 0.0)
		_render_camera.look_at(Vector3.ZERO, Vector3.FORWARD)
		return

	var min_elevation: float = min(view_elevation_degrees_range.x, view_elevation_degrees_range.y)
	var max_elevation: float = max(view_elevation_degrees_range.x, view_elevation_degrees_range.y)
	var elevation := deg_to_rad(randf_range(min_elevation, max_elevation))
	var yaw := randf_range(0.0, TAU)
	var distance: float = max(render_extent * 1.5, 2.0)
	var horizontal_radius := cos(elevation) * distance
	var camera_position := Vector3(
		cos(yaw) * horizontal_radius,
		sin(elevation) * distance,
		sin(yaw) * horizontal_radius
	)

	_render_camera.global_position = camera_position
	_render_camera.look_at(Vector3.ZERO, Vector3.UP)


func _crop_to_alpha_bounds(image: Image) -> Image:
	var alpha_rect := _get_alpha_bounds(image)
	if alpha_rect.size.x <= 0 or alpha_rect.size.y <= 0:
		return image
	return image.get_region(alpha_rect)


func _get_alpha_bounds(image: Image) -> Rect2i:
	var size := image.get_size()
	var min_x := size.x
	var min_y := size.y
	var max_x := -1
	var max_y := -1

	for y in range(size.y):
		for x in range(size.x):
			if image.get_pixel(x, y).a <= 0.02:
				continue
			min_x = min(min_x, x)
			min_y = min(min_y, y)
			max_x = max(max_x, x)
			max_y = max(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func _add_distractor_plane(texture: Texture2D, world_size: Vector2, position: Vector3) -> void:
	var mesh := PlaneMesh.new()
	mesh.size = world_size

	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var plane := MeshInstance3D.new()
	plane.name = "TableDistractor"
	plane.mesh = mesh
	plane.material_override = material
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	plane.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	distractor_parent.add_child(plane)
	plane.global_position = position
	plane.global_rotation = Vector3(0.0, randf_range(0.0, TAU), 0.0)


func _setup_sprite_renderer() -> void:
	if _render_viewport != null:
		return

	_render_viewport = SubViewport.new()
	_render_viewport.name = "DistractorSpriteViewport"
	_render_viewport.disable_3d = false
	_render_viewport.transparent_bg = true
	_render_viewport.own_world_3d = true
	_render_viewport.size = render_size
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_render_viewport)

	_render_root = Node3D.new()
	_render_root.name = "RenderRoot"
	_render_viewport.add_child(_render_root)

	var light := DirectionalLight3D.new()
	light.name = "SpriteLight"
	light.light_energy = 2.0
	light.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	_render_root.add_child(light)

	_render_camera = Camera3D.new()
	_render_camera.name = "SpriteCamera"
	_render_viewport.add_child(_render_camera)


func _clear_render_root() -> void:
	if _render_root == null:
		return
	for child in _render_root.get_children():
		if child is DirectionalLight3D:
			continue
		_render_root.remove_child(child)
		child.free()


func _pick_non_overlapping_table_position(
	table_half_size: Vector2,
	world_size: Vector2,
	occupied_rects: Array[Rect2]
) -> Dictionary:
	var attempts: int = max(1, placement_attempts_per_distractor)
	var best_position := Vector2.ZERO
	var best_rect := Rect2()
	var best_overlap := INF

	for i in range(attempts):
		var position := _pick_table_position(table_half_size, world_size)
		var rect := _make_occupied_rect(position, world_size)
		var overlap := _calculate_overlap_area(rect, occupied_rects)
		if overlap <= 0.0:
			return {
				"position": position,
				"rect": rect,
			}
		if overlap < best_overlap:
			best_overlap = overlap
			best_position = position
			best_rect = rect

	if best_overlap < INF and best_overlap <= world_size.x * world_size.y * 0.05:
		return {
			"position": best_position,
			"rect": best_rect,
		}

	return {}


func _get_reserved_size(world_size: Vector2) -> Vector2:
	var diagonal := world_size.length()
	return Vector2(diagonal, diagonal)


func _pick_table_position(table_half_size: Vector2, world_size: Vector2) -> Vector2:
	var half_width: float = max(0.1, table_half_size.x - edge_margin - world_size.x * 0.5)
	var half_depth: float = max(0.1, table_half_size.y - edge_margin - world_size.y * 0.5)
	return Vector2(
		table_mesh.global_position.x + randf_range(-half_width, half_width),
		table_mesh.global_position.z + randf_range(-half_depth, half_depth)
	)


func _make_occupied_rect(center: Vector2, world_size: Vector2) -> Rect2:
	var padded_size := world_size + Vector2(overlap_padding, overlap_padding) * 2.0
	return Rect2(center - padded_size * 0.5, padded_size)


func _calculate_overlap_area(rect: Rect2, occupied_rects: Array[Rect2]) -> float:
	var total := 0.0
	for occupied in occupied_rects:
		var intersection := rect.intersection(occupied)
		if intersection.size.x <= 0.0 or intersection.size.y <= 0.0:
			continue
		total += intersection.size.x * intersection.size.y
	return total


func get_table_size() -> Vector2:
	if table_mesh == null or table_mesh.mesh == null:
		return Vector2.ZERO
	var aabb := table_mesh.mesh.get_aabb()
	var global_scale := table_mesh.global_transform.basis.get_scale()
	return Vector2(aabb.size.x * global_scale.x, aabb.size.z * global_scale.z) / 2.0


func get_table_top_y() -> float:
	var bounds := get_node_world_bounds(table_mesh)
	if bounds.size == Vector3.ZERO:
		return table_mesh.global_position.y
	return bounds.position.y + bounds.size.y


func pick_weighted_category(categories: Array[ObjectCategory]) -> ObjectCategory:
	var total_weight := 0.0
	for category in categories:
		total_weight += category.weight
	if total_weight <= 0.0:
		return categories[randi() % categories.size()]

	var roll := randf() * total_weight
	var acc := 0.0
	for category in categories:
		acc += category.weight
		if roll < acc:
			return category
	return categories[categories.size() - 1]


func get_node_world_bounds(node: Node3D) -> AABB:
	var vertices: Array[Vector3] = []
	_collect_mesh_aabb_world_vertices(node, vertices)
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


func _collect_mesh_aabb_world_vertices(node: Node, vertices: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh != null:
			var aabb := mesh_instance.mesh.get_aabb()
			_append_box_vertices(
				vertices,
				mesh_instance.global_transform,
				aabb.position,
				aabb.position + aabb.size
			)

	for child in node.get_children():
		_collect_mesh_aabb_world_vertices(child, vertices)


func _append_box_vertices(vertices: Array[Vector3], transform: Transform3D, min_corner: Vector3, max_corner: Vector3) -> void:
	var local_vertices := [
		Vector3(min_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, min_corner.y, min_corner.z),
		Vector3(max_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, max_corner.y, min_corner.z),
		Vector3(min_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, min_corner.y, max_corner.z),
		Vector3(max_corner.x, max_corner.y, max_corner.z),
		Vector3(min_corner.x, max_corner.y, max_corner.z),
	]
	for vertex in local_vertices:
		vertices.append(transform * vertex)


func _freeze_bodies(node: Node) -> void:
	if node is RigidBody3D:
		var body := node as RigidBody3D
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO

	for child in node.get_children():
		_freeze_bodies(child)


func _on_complete_rotation(_rotation: int) -> void:
	if camera == null or not bool(camera.get("active")) or not _running:
		return
	begin()
