extends Node
class_name CameraImageAugmenter

const AUGMENTATION_SHADER := preload("res://shaders/camera_image_augmentation.gdshader")

@export var camera: Node
@export var depth_view: MeshInstance3D

@export_category("Camera Perturbation")
@export var enabled: bool = true
@export var change_time_range: Vector2 = Vector2(1.0, 3.0)

@export_group("Lens Distortion")
@export var distortion_enabled: bool = true
@export var distortion_delta_range: Vector2 = Vector2(-0.06, 0.06)

@export_group("White Balance")
@export var white_balance_enabled: bool = true
@export var warm_cool_range: Vector2 = Vector2(-0.08, 0.08)
@export var green_magenta_range: Vector2 = Vector2(-0.04, 0.04)

var _running := false
var _distortion_strength := 0.0
var _white_balance := Vector3.ONE
var _start_distortion_strength := 0.0
var _target_distortion_strength := 0.0
var _start_white_balance := Vector3.ONE
var _target_white_balance := Vector3.ONE
var _transition_timer := 0.0
var _transition_duration := 1.0
var _effect_layers: Array[CanvasLayer] = []
var _effect_materials: Array[ShaderMaterial] = []


func _ready() -> void:
	var default_layer := create_effect_layer(null)
	add_child(default_layer)
	_apply_current_to_layers()
	_apply_current_to_depth_material()


func begin() -> void:
	_running = true
	_distortion_strength = 0.0
	_white_balance = Vector3.ONE
	_start_new_transition()
	_apply_current_to_layers()
	_apply_current_to_depth_material()


func halt() -> void:
	_running = false
	_distortion_strength = 0.0
	_white_balance = Vector3.ONE
	_start_distortion_strength = 0.0
	_target_distortion_strength = 0.0
	_start_white_balance = Vector3.ONE
	_target_white_balance = Vector3.ONE
	_transition_timer = 0.0
	_apply_current_to_layers()
	_apply_current_to_depth_material()


func apply_settings(
	next_enabled: bool,
	next_distortion_enabled: bool,
	next_distortion_delta_range: Vector2,
	next_white_balance_enabled: bool,
	next_warm_cool_range: Vector2,
	next_green_magenta_range: Vector2,
	next_change_time_range: Vector2 = Vector2(1.0, 3.0)
) -> void:
	enabled = next_enabled
	distortion_enabled = next_distortion_enabled
	distortion_delta_range = _sort_range(next_distortion_delta_range)
	white_balance_enabled = next_white_balance_enabled
	warm_cool_range = _sort_range(next_warm_cool_range)
	green_magenta_range = _sort_range(next_green_magenta_range)
	change_time_range = _sort_range(next_change_time_range)

	if not enabled and _running:
		_distortion_strength = 0.0
		_white_balance = Vector3.ONE
		_apply_current_to_layers()
		_apply_current_to_depth_material()


func _process(delta: float) -> void:
	if not _running:
		return

	if not enabled:
		_distortion_strength = 0.0
		_white_balance = Vector3.ONE
		_apply_current_to_layers()
		_apply_current_to_depth_material()
		return

	_transition_timer += delta
	var progress: float = clamp(_transition_timer / max(_transition_duration, 0.001), 0.0, 1.0)
	var eased_progress := smoothstep(0.0, 1.0, progress)
	_distortion_strength = lerp(_start_distortion_strength, _target_distortion_strength, eased_progress)
	_white_balance = _start_white_balance.lerp(_target_white_balance, eased_progress)
	_apply_current_to_layers()
	_apply_current_to_depth_material()

	if progress >= 1.0:
		_start_new_transition()


func create_effect_layer(custom_viewport: Viewport) -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "CameraImageAugmentation"
	layer.layer = 250
	if custom_viewport != null:
		layer.custom_viewport = custom_viewport

	var rect := ColorRect.new()
	rect.name = "CameraImageAugmentationRect"
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var material := ShaderMaterial.new()
	material.shader = AUGMENTATION_SHADER
	rect.material = material
	layer.add_child(rect)

	_effect_layers.append(layer)
	_effect_materials.append(material)
	_apply_to_layer(layer, material)
	return layer


func _start_new_transition() -> void:
	_start_distortion_strength = _distortion_strength
	_start_white_balance = _white_balance
	_target_distortion_strength = _pick_distortion_strength()
	_target_white_balance = _pick_white_balance()
	_transition_timer = 0.0
	_transition_duration = randf_range(
		max(0.001, change_time_range.x),
		max(0.001, change_time_range.y)
	)


func _pick_distortion_strength() -> float:
	if distortion_enabled:
		return randf_range(distortion_delta_range.x, distortion_delta_range.y)
	return 0.0


func _pick_white_balance() -> Vector3:
	if white_balance_enabled:
		var warm_cool := randf_range(warm_cool_range.x, warm_cool_range.y)
		var green_magenta := randf_range(green_magenta_range.x, green_magenta_range.y)
		return _make_white_balance(warm_cool, green_magenta)
	return Vector3.ONE


func _make_white_balance(warm_cool: float, green_magenta: float) -> Vector3:
	var red: float = clamp(1.0 + warm_cool, 0.5, 1.5)
	var blue: float = clamp(1.0 - warm_cool, 0.5, 1.5)
	var green: float = clamp(1.0 + green_magenta, 0.5, 1.5)
	return Vector3(red, green, blue)


func _apply_current_to_layers() -> void:
	_prune_invalid_layers()
	for i in range(_effect_layers.size()):
		_apply_to_layer(_effect_layers[i], _effect_materials[i])


func _apply_current_to_depth_material() -> void:
	var material := _get_depth_material()
	if material == null:
		return

	var strength := _distortion_strength if enabled and distortion_enabled else 0.0
	material.set_shader_parameter("distortion_strength", strength)
	material.set_shader_parameter("distortion_zoom", _calculate_distortion_zoom(strength))


func _apply_to_layer(layer: CanvasLayer, material: ShaderMaterial) -> void:
	if layer == null or material == null:
		return

	var active := enabled and (_distortion_strength != 0.0 or _white_balance != Vector3.ONE)
	layer.visible = active
	material.set_shader_parameter("distortion_strength", _distortion_strength if distortion_enabled else 0.0)
	material.set_shader_parameter("distortion_zoom", _calculate_distortion_zoom(_distortion_strength))
	material.set_shader_parameter("white_balance", _white_balance if white_balance_enabled else Vector3.ONE)


func _calculate_distortion_zoom(strength: float) -> float:
	# Positive distortion samples outside screen bounds first; zoom in enough to avoid black/cropped edges.
	return 1.0 + abs(strength) * 2.2


func _get_depth_material() -> ShaderMaterial:
	if depth_view == null or not is_instance_valid(depth_view):
		return null
	var material := depth_view.get_active_material(0) as ShaderMaterial
	return material


func _prune_invalid_layers() -> void:
	var valid_layers: Array[CanvasLayer] = []
	var valid_materials: Array[ShaderMaterial] = []
	for i in range(_effect_layers.size()):
		var layer := _effect_layers[i]
		var material := _effect_materials[i]
		if is_instance_valid(layer) and is_instance_valid(material):
			valid_layers.append(layer)
			valid_materials.append(material)
	_effect_layers = valid_layers
	_effect_materials = valid_materials


func _sort_range(value: Vector2) -> Vector2:
	return Vector2(min(value.x, value.y), max(value.x, value.y))
