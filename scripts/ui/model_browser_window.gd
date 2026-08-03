extends Window
class_name ModelBrowserWindow

const BASE_WINDOW_SIZE := Vector2i(1120, 720)
const BASE_MIN_SIZE := Vector2i(960, 640)
const MAX_SCREEN_FILL_RATIO := 0.92
const REFERENCE_SCREEN_HEIGHT := 1080.0
const MIN_UI_SCALE := 1.0
const MAX_UI_SCALE := 1.55
const MIN_CAMERA_DISTANCE := 0.3
const MAX_CAMERA_DISTANCE := 80.0
const DEFAULT_YAW := deg_to_rad(35.0)
const DEFAULT_PITCH := deg_to_rad(20.0)

var object_catalog: ObjectCatalog

var _tree: Tree
var _viewport: SubViewport
var _viewport_container: SubViewportContainer
var _model_root: Node3D
var _camera: Camera3D
var _empty_label: Label

var _target := Vector3.ZERO
var _default_target := Vector3.ZERO
var _orbit_basis := Basis.IDENTITY
var _distance := 5.0
var _model_radius := 1.0
var _is_rotating := false
var _is_panning := false
var _last_mouse_position := Vector2.ZERO
var _scale_source_window: Window
var _last_applied_ui_scale := -1.0


func _init() -> void:
	visible = false
	force_native = true


func _ready() -> void:
	title = "Model Browser"
	_apply_realtime_ui_scale(true)
	set_process(true)
	close_requested.connect(hide)
	_build_ui()
	if object_catalog != null:
		populate(object_catalog)


func _process(_delta: float) -> void:
	if visible:
		_apply_realtime_ui_scale(false)


func setup(catalog: ObjectCatalog) -> void:
	object_catalog = catalog
	if is_inside_tree() and _tree != null:
		populate(catalog)


func sync_content_scale_from(source_window: Window) -> void:
	if source_window == null:
		return
	_scale_source_window = source_window
	content_scale_mode = source_window.content_scale_mode
	content_scale_aspect = source_window.content_scale_aspect
	_apply_realtime_ui_scale(true)


func get_preferred_popup_size() -> Vector2i:
	return _calculate_scaled_window_size(BASE_WINDOW_SIZE)


func _apply_realtime_ui_scale(update_window_size: bool) -> void:
	var ui_scale := _calculate_current_ui_scale()
	if _scale_source_window != null and is_instance_valid(_scale_source_window):
		content_scale_mode = _scale_source_window.content_scale_mode
		content_scale_aspect = _scale_source_window.content_scale_aspect
	else:
		content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND

	if not is_equal_approx(ui_scale, _last_applied_ui_scale):
		content_scale_factor = ui_scale
		min_size = _calculate_scaled_window_size(BASE_MIN_SIZE)
		_last_applied_ui_scale = ui_scale

	if update_window_size:
		size = _calculate_scaled_window_size(BASE_WINDOW_SIZE)


func _calculate_current_ui_scale() -> float:
	var usable_rect := _get_safe_usable_rect()
	var usable_size := usable_rect.size
	if usable_size.x <= 0 or usable_size.y <= 0:
		if _scale_source_window != null and is_instance_valid(_scale_source_window):
			return max(float(_scale_source_window.content_scale_factor), MIN_UI_SCALE)
		return MIN_UI_SCALE

	var height_scale := float(usable_size.y) / REFERENCE_SCREEN_HEIGHT
	return clamp(height_scale, MIN_UI_SCALE, MAX_UI_SCALE)


func _calculate_scaled_window_size(base_size: Vector2i) -> Vector2i:
	var scale: float = max(float(content_scale_factor), 1.0)
	var target: Vector2 = Vector2(base_size) * scale
	var usable_rect: Rect2i = _get_safe_usable_rect()
	if usable_rect.size.x > 0 and usable_rect.size.y > 0:
		var max_size: Vector2 = Vector2(usable_rect.size) * MAX_SCREEN_FILL_RATIO
		target.x = min(target.x, max_size.x)
		target.y = min(target.y, max_size.y)
	return Vector2i(round(target.x), round(target.y))


func _get_safe_usable_rect() -> Rect2i:
	var screen := _get_safe_screen_index()
	if screen < 0:
		return Rect2i()
	return DisplayServer.screen_get_usable_rect(screen)


func _get_safe_screen_index() -> int:
	var screen_count := DisplayServer.get_screen_count()
	if screen_count <= 0:
		return -1

	if _scale_source_window != null and is_instance_valid(_scale_source_window):
		var source_screen := DisplayServer.window_get_current_screen(_scale_source_window.get_window_id())
		if _is_valid_screen_index(source_screen, screen_count):
			return source_screen

	if visible:
		var current_screen := DisplayServer.window_get_current_screen(get_window_id())
		if _is_valid_screen_index(current_screen, screen_count):
			return current_screen

	var main_window := get_tree().root
	if main_window != null:
		var main_screen := DisplayServer.window_get_current_screen(main_window.get_window_id())
		if _is_valid_screen_index(main_screen, screen_count):
			return main_screen

	return 0


func _is_valid_screen_index(screen: int, screen_count: int) -> bool:
	return screen >= 0 and screen < screen_count


func populate(catalog: ObjectCatalog) -> void:
	object_catalog = catalog
	if _tree == null:
		return

	_tree.clear()
	var root := _tree.create_item()
	if catalog == null:
		return

	var official_item := _tree.create_item(root)
	official_item.set_text(0, "Official")
	official_item.set_selectable(0, false)
	official_item.collapsed = false
	_populate_category_group(official_item, catalog.get_official_categories())

	var unknown_item := _tree.create_item(root)
	unknown_item.set_text(0, "Unknown")
	unknown_item.set_selectable(0, false)
	unknown_item.collapsed = false
	_populate_category_group(unknown_item, catalog.get_unknown_categories())

	_select_first_scene(root)


func _populate_category_group(parent_item: TreeItem, categories: Array[ObjectCategory]) -> void:
	for category in categories:
		if category == null:
			continue

		var category_item := _tree.create_item(parent_item)
		category_item.set_text(0, str(category.display_name))
		category_item.set_selectable(0, false)
		category_item.collapsed = false

		for scene in category.scenes:
			if scene == null:
				continue
			var scene_item := _tree.create_item(category_item)
			scene_item.set_text(0, _get_scene_display_name(scene))
			scene_item.set_metadata(0, scene)


func _build_ui() -> void:
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 10)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_right", 10)
	root.add_theme_constant_override("margin_bottom", 10)
	add_child(root)

	var split := HSplitContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 280
	root.add_child(split)

	_tree = Tree.new()
	_tree.custom_minimum_size = Vector2(280, 0)
	_tree.hide_root = true
	_tree.size_flags_horizontal = Control.SIZE_FILL
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.item_selected.connect(_on_tree_item_selected)
	split.add_child(_tree)

	var preview_panel := VBoxContainer.new()
	preview_panel.add_theme_constant_override("separation", 8)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(preview_panel)

	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 8)
	preview_panel.add_child(toolbar)

	var hint := Label.new()
	hint.text = "Left drag: rotate    Right drag: pan    Wheel: zoom"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(hint)

	var reset_button := Button.new()
	reset_button.text = "Reset View"
	reset_button.pressed.connect(_reset_view)
	toolbar.add_child(reset_button)

	_viewport_container = SubViewportContainer.new()
	_viewport_container.custom_minimum_size = Vector2(640, 480)
	_viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_viewport_container.stretch = true
	_viewport_container.gui_input.connect(_on_preview_input)
	preview_panel.add_child(_viewport_container)

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(800, 600)
	_viewport.own_world_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport_container.add_child(_viewport)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#151922")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0
	environment.environment = env
	_viewport.add_child(environment)

	_model_root = Node3D.new()
	_model_root.name = "ModelRoot"
	_viewport.add_child(_model_root)

	var key_light := DirectionalLight3D.new()
	key_light.name = "KeyLight"
	key_light.light_energy = 1.8
	key_light.rotation = Vector3(deg_to_rad(-45.0), deg_to_rad(35.0), 0.0)
	_viewport.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.name = "FillLight"
	fill_light.light_energy = 0.4
	fill_light.omni_range = 10.0
	fill_light.position = Vector3(-3.0, 4.0, 3.0)
	_viewport.add_child(fill_light)

	_camera = Camera3D.new()
	_camera.name = "PreviewCamera"
	_camera.fov = 45.0
	_camera.near = 0.01
	_camera.far = 200.0
	_camera.current = true
	_viewport.add_child(_camera)

	_empty_label = Label.new()
	_empty_label.text = "Select a model from the left list."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_viewport_container.add_child(_empty_label)

	_update_camera()


func _on_tree_item_selected() -> void:
	var selected := _tree.get_selected()
	if selected == null:
		return

	var scene := selected.get_metadata(0) as PackedScene
	if scene == null:
		return

	_load_scene(scene)


func _load_scene(scene: PackedScene) -> void:
	_clear_model()

	var instance := scene.instantiate() as Node3D
	if instance == null:
		_empty_label.text = "Unable to preview this scene."
		_empty_label.visible = true
		return

	_model_root.add_child(instance)
	_freeze_bodies(instance)
	_center_model(instance)
	_reset_view()
	_empty_label.visible = false


func _clear_model() -> void:
	for child in _model_root.get_children():
		child.queue_free()
	_empty_label.visible = true


func _center_model(instance: Node3D) -> void:
	var bounds := _get_node_world_bounds(instance)
	if bounds.size == Vector3.ZERO:
		instance.global_position = Vector3.ZERO
		_target = Vector3.ZERO
		_default_target = _target
		_model_radius = 1.0
		return

	var center := bounds.position + bounds.size * 0.5
	instance.global_position -= center

	var centered_bounds := _get_node_world_bounds(instance)
	_target = centered_bounds.position + centered_bounds.size * 0.5
	_default_target = _target
	_model_radius = max(centered_bounds.size.length() * 0.5, 0.2)
	_distance = clamp(_model_radius * 2.8, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)


func _reset_view() -> void:
	_target = _default_target
	_orbit_basis = _make_default_orbit_basis()
	_distance = clamp(_model_radius * 2.8, MIN_CAMERA_DISTANCE, MAX_CAMERA_DISTANCE)
	_update_camera()


func _make_default_orbit_basis() -> Basis:
	return Basis(Quaternion(Vector3.UP, DEFAULT_YAW)) * Basis(Quaternion(Vector3.RIGHT, -DEFAULT_PITCH))


func _on_preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_is_rotating = mouse_button.pressed
			_last_mouse_position = mouse_button.position
		elif mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			_is_panning = mouse_button.pressed
			_last_mouse_position = mouse_button.position
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = max(MIN_CAMERA_DISTANCE, _distance * 0.9)
			_update_camera()
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = min(MAX_CAMERA_DISTANCE, _distance * 1.1)
			_update_camera()
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		var delta := motion.position - _last_mouse_position
		_last_mouse_position = motion.position
		if _is_rotating:
			_rotate_view(delta)
			_update_camera()
		elif _is_panning:
			_pan_view(delta)


func _rotate_view(delta: Vector2) -> void:
	var yaw_rotation := Basis(Quaternion(Vector3.UP, -delta.x * 0.01))
	var right_axis := (_orbit_basis * Vector3.RIGHT).normalized()
	var pitch_rotation := Basis(Quaternion(right_axis, -delta.y * 0.01))
	_orbit_basis = (pitch_rotation * yaw_rotation * _orbit_basis).orthonormalized()


func _pan_view(delta: Vector2) -> void:
	if _camera == null:
		return
	var pan_scale := _distance * 0.0018
	var right := _orbit_basis.x
	var up := _orbit_basis.y
	_target += (-right * delta.x + up * delta.y) * pan_scale
	_update_camera()


func _update_camera() -> void:
	if _camera == null:
		return

	var direction := (_orbit_basis * Vector3.BACK).normalized()
	_camera.global_position = _target + direction * _distance
	_camera.global_basis = _orbit_basis


func _select_first_scene(root: TreeItem) -> void:
	if root == null:
		return
	var scene_item := _find_first_scene_item(root)
	if scene_item == null:
		return
	scene_item.select(0)
	_load_scene(scene_item.get_metadata(0) as PackedScene)


func _find_first_scene_item(parent_item: TreeItem) -> TreeItem:
	var child := parent_item.get_first_child()
	while child != null:
		if child.get_metadata(0) is PackedScene:
			return child
		var nested := _find_first_scene_item(child)
		if nested != null:
			return nested
		child = child.get_next()
	return null


func _get_scene_display_name(scene: PackedScene) -> String:
	var path := scene.resource_path
	if path.is_empty():
		return "Unnamed Scene"
	return path.get_file().get_basename()


func _freeze_bodies(node: Node) -> void:
	if node is RigidBody3D:
		var body := node as RigidBody3D
		body.freeze = true
		body.linear_velocity = Vector3.ZERO
		body.angular_velocity = Vector3.ZERO
	for child in node.get_children():
		_freeze_bodies(child)


func _get_node_world_bounds(node: Node3D) -> AABB:
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
