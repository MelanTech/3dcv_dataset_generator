extends Control

const SessionPanelBuilderScript = preload("res://scripts/ui/session_panel_builder.gd")

## 采集会话总控 + GUI 面板。
##
## 状态机：Idle（待命）/ Running（运行）。
## - Idle：相机停转停在初值姿态、桌面清空、不存图。程序启动即 Idle。
## - Running：相机自动转圈+过渡、物品自动重摆、按间隔连续存（若开启保存）。
## GUI 位于主界面右侧面板，3D 画面在左侧 SubViewportContainer 中。

@export var camera: Node
@export var random_placer: Node
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
var _interval_spin: SpinBox
var _save_depth_check: CheckBox
var _save_enabled_check: CheckBox
var _show_bbox_check: CheckBox
var _rotate_light_check: CheckBox
var _table_option: OptionButton
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
	if data_generator != null and data_generator.has_method("begin"):
		data_generator.begin()
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
	if data_generator != null:
		data_generator.base_path = _output_dir
		data_generator.save_interval = int(_interval_spin.value)
		data_generator.save_depth = _save_depth_check.button_pressed
		data_generator.save_enabled = _save_enabled_check.button_pressed
	if random_placer != null:
		random_placer.item_count_range = Vector2i(int(_count_min.value), int(_count_max.value))


func _sync_catalog_from_controls() -> void:
	for key in _category_controls:
		var ctrl = _category_controls[key]
		var category: ObjectCategory = ctrl.category
		if category == null:
			continue
		category.enabled = ctrl.enabled.button_pressed
		category.weight = float(ctrl.weight.value)


# ----------------------------------------------------------------------------
# 配置持久化
# ----------------------------------------------------------------------------
func _on_save_config_pressed() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "output_dir", _output_dir)
	cfg.set_value("general", "count_min", int(_count_min.value))
	cfg.set_value("general", "count_max", int(_count_max.value))
	cfg.set_value("general", "save_interval", int(_interval_spin.value))
	cfg.set_value("general", "save_depth", _save_depth_check.button_pressed)
	cfg.set_value("general", "save_enabled", _save_enabled_check.button_pressed)
	cfg.set_value("general", "show_bbox", _show_bbox_check.button_pressed)
	cfg.set_value("general", "rotate_light", _rotate_light_check.button_pressed)
	cfg.set_value("general", "table_shape", _table_option.selected)
	for prefix in _category_controls:
		var ctrl = _category_controls[prefix]
		cfg.set_value("enabled", prefix, ctrl.enabled.button_pressed)
		cfg.set_value("weight", prefix, float(ctrl.weight.value))
	cfg.save(CONFIG_PATH)
	print("[session] config saved to %s" % CONFIG_PATH)


func _load_config() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) != OK:
		return
	_output_dir = cfg.get_value("general", "output_dir", _output_dir)
	_output_dir_value.text = _output_dir
	_count_min.value = cfg.get_value("general", "count_min", _count_min.value)
	_count_max.value = cfg.get_value("general", "count_max", _count_max.value)
	_interval_spin.value = cfg.get_value("general", "save_interval", _interval_spin.value)
	_save_depth_check.button_pressed = cfg.get_value("general", "save_depth", false)
	_save_enabled_check.button_pressed = cfg.get_value("general", "save_enabled", false)
	_show_bbox_check.button_pressed = cfg.get_value("general", "show_bbox", true)
	_rotate_light_check.button_pressed = cfg.get_value("general", "rotate_light", true)
	_table_option.selected = cfg.get_value("general", "table_shape", 0)
	for prefix in _category_controls:
		var ctrl = _category_controls[prefix]
		var category: ObjectCategory = ctrl.category
		var default_enabled := category.enabled if category != null else true
		var default_weight := category.weight if category != null else 1.0
		ctrl.enabled.button_pressed = cfg.get_value("enabled", prefix, default_enabled)
		ctrl.weight.value = cfg.get_value("weight", prefix, default_weight)


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
	_interval_spin = controls["interval_spin"]
	_save_depth_check = controls["save_depth_check"]
	_save_enabled_check = controls["save_enabled_check"]
	_show_bbox_check = controls["show_bbox_check"]
	_rotate_light_check = controls["rotate_light_check"]
	_table_option = controls["table_option"]
	_start_btn = controls["start_btn"]
	_stop_btn = controls["stop_btn"]
	_status_label = controls["status_label"]
	_category_controls = controls["category_controls"]


# 启动后禁用结构性配置控件（保存/预览开关除外）
func _set_structural_config_disabled(disabled: bool) -> void:
	# SpinBox 用 editable，其余用 disabled
	for spin in [_count_min, _count_max, _interval_spin]:
		if spin != null:
			spin.editable = not disabled
	if _save_depth_check != null:
		_save_depth_check.disabled = disabled
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
		_file_dialog.use_native_dialog = true
		_file_dialog.dir_selected.connect(_on_dir_selected)
		add_child(_file_dialog)
	if not _output_dir.is_empty():
		_file_dialog.current_dir = _output_dir
	_file_dialog.popup_centered(Vector2i(800, 600))


func _on_dir_selected(dir: String) -> void:
	_output_dir = dir
	_output_dir_value.text = dir
