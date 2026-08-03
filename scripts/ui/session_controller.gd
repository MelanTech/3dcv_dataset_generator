extends Control

const CaptureSettingsScript = preload("res://scripts/ui/capture_settings.gd")
const SessionPanelBuilderScript = preload("res://scripts/ui/session_panel_builder.gd")

## 采集会话总控 + GUI 面板。
##
## 状态机：Idle（待命）/ Running（运行）。
## - Idle：相机停转停在初值姿态、桌面清空、不存图。程序启动即 Idle。
## - Running：相机自动转圈+过渡、物品自动重摆、按间隔连续存（若开启保存）。
## GUI 位于主界面右侧面板，3D 画面在左侧 SubViewportContainer 中。

@export var camera: Node
@export var camera_image_augmenter: Node
@export var random_placer: Node
@export var table_distractor_placer: Node
@export var data_generator: Node
@export var bbox_layer: CanvasItem
@export var table_selector: Node
@export var rotate_light: Node3D
@export var object_catalog: ObjectCatalog

const CONFIG_PATH := "user://gui_config.cfg"

var _running := false

# GUI 控件引用
var _output_dir_value: Label
var _count_min: SpinBox
var _count_max: SpinBox
var _distractor_enabled_check: CheckBox
var _distractor_count_min: SpinBox
var _distractor_count_max: SpinBox
var _interval_spin: SpinBox
var _save_depth_check: CheckBox
var _save_enabled_check: CheckBox
var _show_bbox_check: CheckBox
var _rotate_light_check: CheckBox
var _table_option: OptionButton
var _visibility_threshold: SpinBox
var _occlusion_sample_mode: OptionButton
var _occlusion_grid_sample_count: SpinBox
var _drop_below_table_threshold: SpinBox
var _debug_occlusion_check: CheckBox
var _camera_rotation_speed: SpinBox
var _camera_transition_duration: SpinBox
var _camera_distance_min: SpinBox
var _camera_distance_max: SpinBox
var _camera_height_min: SpinBox
var _camera_height_max: SpinBox
var _camera_rotation_x_min: SpinBox
var _camera_rotation_x_max: SpinBox
var _camera_rotation_y_min: SpinBox
var _camera_rotation_y_max: SpinBox
var _camera_rotation_z_min: SpinBox
var _camera_rotation_z_max: SpinBox
var _camera_perturb_enabled_check: CheckBox
var _camera_change_time_min: SpinBox
var _camera_change_time_max: SpinBox
var _camera_distortion_enabled_check: CheckBox
var _distortion_delta_min: SpinBox
var _distortion_delta_max: SpinBox
var _white_balance_enabled_check: CheckBox
var _warm_cool_min: SpinBox
var _warm_cool_max: SpinBox
var _green_magenta_min: SpinBox
var _green_magenta_max: SpinBox
var _start_btn: Button
var _stop_btn: Button
var _status_label: Label
# 每类别控件：prefix -> {"enabled": CheckBox, "weight": SpinBox}
var _category_controls := {}

var _output_dir := ""
var _file_dialog: FileDialog


func _ready() -> void:
	# 默认从 data_generator 读出输出目录初值
	if data_generator != null:
		_output_dir = str(data_generator.base_path)
	_resolve_object_catalog()
	_build_gui()
	_load_config()
	_sync_catalog_from_controls()
	_apply_realtime_settings()
	_set_running(false)


func _resolve_object_catalog() -> void:
	if object_catalog != null:
		return
	if random_placer != null:
		object_catalog = random_placer.get("object_catalog") as ObjectCatalog


# ----------------------------------------------------------------------------
# 会话控制
# ----------------------------------------------------------------------------
func _on_start_pressed() -> void:
	if _running:
		return
	_apply_config_to_nodes()
	if camera != null and camera.has_method("begin"):
		camera.begin()
	if camera_image_augmenter != null and camera_image_augmenter.has_method("begin"):
		camera_image_augmenter.begin()
	if data_generator != null and data_generator.has_method("begin"):
		data_generator.begin()
	if table_distractor_placer != null and table_distractor_placer.has_method("begin"):
		table_distractor_placer.begin()
	if random_placer != null and random_placer.has_method("begin"):
		random_placer.begin()
	_set_running(true)


func _on_stop_pressed() -> void:
	if not _running:
		return
	# 存完当前帧再停：若正卡在保存的 await 中，等它结束
	if data_generator != null:
		while data_generator._saving:
			await get_tree().process_frame
	if data_generator != null and data_generator.has_method("halt"):
		data_generator.halt()
	if random_placer != null and random_placer.has_method("halt"):
		random_placer.halt()
	if table_distractor_placer != null and table_distractor_placer.has_method("halt"):
		table_distractor_placer.halt()
	if camera_image_augmenter != null and camera_image_augmenter.has_method("halt"):
		camera_image_augmenter.halt()
	if camera != null and camera.has_method("halt"):
		camera.halt()
	_set_running(false)


func _set_running(value: bool) -> void:
	_running = value
	if _start_btn != null:
		_start_btn.disabled = value
	if _stop_btn != null:
		_stop_btn.disabled = not value
	# Running 中禁止改这些结构性配置（保存开关/预览开关仍可实时改）
	_set_structural_config_disabled(value)
	_update_status()


func _process(_delta: float) -> void:
	if _running:
		_update_status()


func _update_status() -> void:
	if _status_label == null:
		return
	var state := "Running" if _running else "Idle"
	var saved := 0
	var folder := "-"
	if data_generator != null:
		saved = data_generator.frame_count
		folder = str(data_generator.folder_name) if not str(data_generator.folder_name).is_empty() else "-"
	_status_label.text = "State: %s    Saved: %d    Folder: %s" % [state, saved, folder]


# ----------------------------------------------------------------------------
# 配置应用
# ----------------------------------------------------------------------------
# 实时项：保存开关、预览框、桌子形状
func _apply_realtime_settings() -> void:
	if data_generator != null and _save_enabled_check != null:
		data_generator.save_enabled = _save_enabled_check.button_pressed
	if bbox_layer != null and _show_bbox_check != null:
		bbox_layer.visible = _show_bbox_check.button_pressed
	if rotate_light != null and _rotate_light_check != null:
		rotate_light.visible = _rotate_light_check.button_pressed
	if table_selector != null and _table_option != null:
		table_selector.set("table_shape", _table_option.selected)


func _on_save_enabled_toggled(pressed: bool) -> void:
	if data_generator != null:
		data_generator.save_enabled = pressed


func _on_show_bbox_toggled(pressed: bool) -> void:
	if bbox_layer != null:
		bbox_layer.visible = pressed


func _on_rotate_light_toggled(pressed: bool) -> void:
	if rotate_light != null:
		rotate_light.visible = pressed


func _on_table_shape_selected(index: int) -> void:
	if table_selector != null:
		table_selector.set("table_shape", index)


# 启动时把 GUI 配置推入各节点
func _apply_config_to_nodes() -> void:
	_sync_catalog_from_controls()
	if table_selector != null and _table_option != null:
		table_selector.set("table_shape", _table_option.selected)
		if table_selector.has_method("_apply_table_selection"):
			table_selector.call("_apply_table_selection")
	if data_generator != null:
		data_generator.base_path = _output_dir
		data_generator.save_interval = int(_interval_spin.value)
		data_generator.save_depth = _save_depth_check.button_pressed
		data_generator.save_enabled = _save_enabled_check.button_pressed
		data_generator.visibility_threshold = int(_visibility_threshold.value)
		data_generator.occlusion_sample_mode = _occlusion_sample_mode.selected
		data_generator.occlusion_grid_sample_count = int(_occlusion_grid_sample_count.value)
		data_generator.drop_below_table_threshold = float(_drop_below_table_threshold.value)
		data_generator.debug_occlusion = _debug_occlusion_check.button_pressed
	if random_placer != null:
		random_placer.item_count_range = Vector2i(int(_count_min.value), int(_count_max.value))
	if table_distractor_placer != null:
		table_distractor_placer.set("enabled", _distractor_enabled_check.button_pressed and _table_option.selected != 2)
		table_distractor_placer.set(
			"distractor_count_range",
			Vector2i(int(_distractor_count_min.value), int(_distractor_count_max.value))
		)
	if camera != null:
		camera.set("rotation_speed", float(_camera_rotation_speed.value))
		camera.set("transition_duration", float(_camera_transition_duration.value))
		camera.set(
			"distance_range",
			_make_sorted_vector2(float(_camera_distance_min.value), float(_camera_distance_max.value))
		)
		camera.set(
			"height_range",
			_make_sorted_vector2(float(_camera_height_min.value), float(_camera_height_max.value))
		)
		camera.set(
			"rotation_x_range",
			_make_sorted_vector2(float(_camera_rotation_x_min.value), float(_camera_rotation_x_max.value))
		)
		camera.set(
			"rotation_y_range",
			_make_sorted_vector2(float(_camera_rotation_y_min.value), float(_camera_rotation_y_max.value))
		)
		camera.set(
			"rotation_z_range",
			_make_sorted_vector2(float(_camera_rotation_z_min.value), float(_camera_rotation_z_max.value))
		)
	if camera_image_augmenter != null:
		camera_image_augmenter.call(
			"apply_settings",
			_camera_perturb_enabled_check.button_pressed,
			_camera_distortion_enabled_check.button_pressed,
			Vector2(float(_distortion_delta_min.value), float(_distortion_delta_max.value)),
			_white_balance_enabled_check.button_pressed,
			Vector2(float(_warm_cool_min.value), float(_warm_cool_max.value)),
			Vector2(float(_green_magenta_min.value), float(_green_magenta_max.value)),
			Vector2(float(_camera_change_time_min.value), float(_camera_change_time_max.value))
		)


func _sync_catalog_from_controls() -> void:
	for key in _category_controls:
		var ctrl = _category_controls[key]
		var category: ObjectCategory = ctrl.category
		if category == null:
			continue
		category.enabled = ctrl.enabled.button_pressed
		category.weight = float(ctrl.weight.value)


func _make_sorted_vector2(a: float, b: float) -> Vector2:
	return Vector2(min(a, b), max(a, b))


# ----------------------------------------------------------------------------
# 配置持久化
# ----------------------------------------------------------------------------
func _on_save_config_pressed() -> void:
	var settings: CaptureSettings = CaptureSettingsScript.from_controls(_output_dir, _get_controls())
	var err := settings.save_to_file(CONFIG_PATH)
	if err == OK:
		print("[session] config saved to %s" % CONFIG_PATH)
	else:
		push_error("[session] config save failed: %s (err=%d)" % [CONFIG_PATH, err])


func _load_config() -> void:
	var defaults: CaptureSettings = CaptureSettingsScript.from_controls(_output_dir, _get_controls())
	var settings: CaptureSettings = CaptureSettingsScript.load_from_file(CONFIG_PATH, defaults)
	settings.apply_to_controls(_get_controls())
	_output_dir = settings.output_dir


# ----------------------------------------------------------------------------
# GUI 构建
# ----------------------------------------------------------------------------
func _build_gui() -> void:
	var controls: Dictionary = SessionPanelBuilderScript.build(
		self,
		_output_dir,
		object_catalog,
		{
			"open_dir": _open_dir_dialog,
			"table_shape_selected": _on_table_shape_selected,
			"save_enabled_toggled": _on_save_enabled_toggled,
			"show_bbox_toggled": _on_show_bbox_toggled,
			"rotate_light_toggled": _on_rotate_light_toggled,
			"start": _on_start_pressed,
			"stop": _on_stop_pressed,
			"save_config": _on_save_config_pressed,
		}
	)

	_output_dir_value = controls["output_dir_value"]
	_count_min = controls["count_min"]
	_count_max = controls["count_max"]
	_distractor_enabled_check = controls["distractor_enabled_check"]
	_distractor_count_min = controls["distractor_count_min"]
	_distractor_count_max = controls["distractor_count_max"]
	_interval_spin = controls["interval_spin"]
	_save_depth_check = controls["save_depth_check"]
	_save_enabled_check = controls["save_enabled_check"]
	_show_bbox_check = controls["show_bbox_check"]
	_rotate_light_check = controls["rotate_light_check"]
	_table_option = controls["table_option"]
	_visibility_threshold = controls["visibility_threshold"]
	_occlusion_sample_mode = controls["occlusion_sample_mode"]
	_occlusion_grid_sample_count = controls["occlusion_grid_sample_count"]
	_drop_below_table_threshold = controls["drop_below_table_threshold"]
	_debug_occlusion_check = controls["debug_occlusion_check"]
	_camera_rotation_speed = controls["camera_rotation_speed"]
	_camera_transition_duration = controls["camera_transition_duration"]
	_camera_distance_min = controls["camera_distance_min"]
	_camera_distance_max = controls["camera_distance_max"]
	_camera_height_min = controls["camera_height_min"]
	_camera_height_max = controls["camera_height_max"]
	_camera_rotation_x_min = controls["camera_rotation_x_min"]
	_camera_rotation_x_max = controls["camera_rotation_x_max"]
	_camera_rotation_y_min = controls["camera_rotation_y_min"]
	_camera_rotation_y_max = controls["camera_rotation_y_max"]
	_camera_rotation_z_min = controls["camera_rotation_z_min"]
	_camera_rotation_z_max = controls["camera_rotation_z_max"]
	_camera_perturb_enabled_check = controls["camera_perturb_enabled_check"]
	_camera_change_time_min = controls["camera_change_time_min"]
	_camera_change_time_max = controls["camera_change_time_max"]
	_camera_distortion_enabled_check = controls["camera_distortion_enabled_check"]
	_distortion_delta_min = controls["distortion_delta_min"]
	_distortion_delta_max = controls["distortion_delta_max"]
	_white_balance_enabled_check = controls["white_balance_enabled_check"]
	_warm_cool_min = controls["warm_cool_min"]
	_warm_cool_max = controls["warm_cool_max"]
	_green_magenta_min = controls["green_magenta_min"]
	_green_magenta_max = controls["green_magenta_max"]
	_start_btn = controls["start_btn"]
	_stop_btn = controls["stop_btn"]
	_status_label = controls["status_label"]
	_category_controls = controls["category_controls"]


func _get_controls() -> Dictionary:
	return {
		"output_dir_value": _output_dir_value,
		"count_min": _count_min,
		"count_max": _count_max,
		"distractor_enabled_check": _distractor_enabled_check,
		"distractor_count_min": _distractor_count_min,
		"distractor_count_max": _distractor_count_max,
		"interval_spin": _interval_spin,
		"save_depth_check": _save_depth_check,
		"save_enabled_check": _save_enabled_check,
		"show_bbox_check": _show_bbox_check,
		"rotate_light_check": _rotate_light_check,
		"table_option": _table_option,
		"visibility_threshold": _visibility_threshold,
		"occlusion_sample_mode": _occlusion_sample_mode,
		"occlusion_grid_sample_count": _occlusion_grid_sample_count,
		"drop_below_table_threshold": _drop_below_table_threshold,
		"debug_occlusion_check": _debug_occlusion_check,
		"camera_rotation_speed": _camera_rotation_speed,
		"camera_transition_duration": _camera_transition_duration,
		"camera_distance_min": _camera_distance_min,
		"camera_distance_max": _camera_distance_max,
		"camera_height_min": _camera_height_min,
		"camera_height_max": _camera_height_max,
		"camera_rotation_x_min": _camera_rotation_x_min,
		"camera_rotation_x_max": _camera_rotation_x_max,
		"camera_rotation_y_min": _camera_rotation_y_min,
		"camera_rotation_y_max": _camera_rotation_y_max,
		"camera_rotation_z_min": _camera_rotation_z_min,
		"camera_rotation_z_max": _camera_rotation_z_max,
		"camera_perturb_enabled_check": _camera_perturb_enabled_check,
		"camera_change_time_min": _camera_change_time_min,
		"camera_change_time_max": _camera_change_time_max,
		"camera_distortion_enabled_check": _camera_distortion_enabled_check,
		"distortion_delta_min": _distortion_delta_min,
		"distortion_delta_max": _distortion_delta_max,
		"white_balance_enabled_check": _white_balance_enabled_check,
		"warm_cool_min": _warm_cool_min,
		"warm_cool_max": _warm_cool_max,
		"green_magenta_min": _green_magenta_min,
		"green_magenta_max": _green_magenta_max,
		"category_controls": _category_controls,
	}


# 启动后禁用结构性配置控件（保存/预览开关除外）
func _set_structural_config_disabled(disabled: bool) -> void:
	# SpinBox 用 editable，其余用 disabled
	for spin in [
		_count_min,
		_count_max,
		_distractor_count_min,
		_distractor_count_max,
		_interval_spin,
		_visibility_threshold,
		_occlusion_grid_sample_count,
		_drop_below_table_threshold,
		_camera_rotation_speed,
		_camera_transition_duration,
		_camera_distance_min,
		_camera_distance_max,
		_camera_height_min,
		_camera_height_max,
		_camera_rotation_x_min,
		_camera_rotation_x_max,
		_camera_rotation_y_min,
		_camera_rotation_y_max,
		_camera_rotation_z_min,
		_camera_rotation_z_max,
		_camera_change_time_min,
		_camera_change_time_max,
		_distortion_delta_min,
		_distortion_delta_max,
		_warm_cool_min,
		_warm_cool_max,
		_green_magenta_min,
		_green_magenta_max,
	]:
		if spin != null:
			spin.editable = not disabled
	if _distractor_enabled_check != null:
		_distractor_enabled_check.disabled = disabled
	if _camera_perturb_enabled_check != null:
		_camera_perturb_enabled_check.disabled = disabled
	if _camera_distortion_enabled_check != null:
		_camera_distortion_enabled_check.disabled = disabled
	if _white_balance_enabled_check != null:
		_white_balance_enabled_check.disabled = disabled
	if _save_depth_check != null:
		_save_depth_check.disabled = disabled
	if _occlusion_sample_mode != null:
		_occlusion_sample_mode.disabled = disabled
	if _debug_occlusion_check != null:
		_debug_occlusion_check.disabled = disabled
	if _table_option != null:
		_table_option.disabled = disabled
	for prefix in _category_controls:
		var ctrl = _category_controls[prefix]
		ctrl.enabled.disabled = disabled
		ctrl.weight.editable = not disabled


# ----------------------------------------------------------------------------
# 目录选择对话框
# ----------------------------------------------------------------------------
func _open_dir_dialog() -> void:
	if _file_dialog == null:
		_file_dialog = FileDialog.new()
		_file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		_file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
		_file_dialog.use_native_dialog = false
		_file_dialog.dir_selected.connect(_on_dir_selected)
		add_child(_file_dialog)
	if not _output_dir.is_empty():
		_file_dialog.current_dir = _output_dir
	_file_dialog.popup_centered(Vector2i(800, 600))


func _on_dir_selected(dir: String) -> void:
	_output_dir = dir
	_output_dir_value.text = dir
