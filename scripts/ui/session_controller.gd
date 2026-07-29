extends Control

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

const CONFIG_PATH := "user://gui_config.cfg"

# 类别定义：显示名 -> random_placer 上的属性前缀
const OFFICIAL_CATEGORIES := [
	["Brush", "brush"], ["Earphone", "earphone"], ["Cup", "cup"], ["Hanger", "hanger"],
	["Chocolate", "chocolate"], ["SunflowerSeeds", "sunflower_seeds"], ["Sausage", "sausage"],
	["Chips", "chips"], ["CannedChips", "canned_chips"], ["Can", "can"], ["Bottle", "bottle"],
	["Milk", "milk"], ["Water", "water"], ["Peach", "peach"], ["Apple", "apple"],
	["Banana", "banana"], ["Pear", "pear"], ["Book", "book"],
]
const UNKNOWN_CATEGORIES := [
	["Comb", "comb"], ["Biscuit", "biscuit"], ["DragonFruit", "dragon_fruit"],
	["Orange", "orange"], ["Pomegranate", "pomegranate"], ["Jelly", "jelly"],
]

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
	_build_gui()
	_load_config()
	_apply_realtime_settings()
	_set_running(false)


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
	if data_generator != null:
		data_generator.base_path = _output_dir
		data_generator.save_interval = int(_interval_spin.value)
		data_generator.save_depth = _save_depth_check.button_pressed
		data_generator.save_enabled = _save_enabled_check.button_pressed
	if random_placer != null:
		random_placer.item_count_range = Vector2i(int(_count_min.value), int(_count_max.value))
		for prefix in _category_controls:
			var ctrl = _category_controls[prefix]
			random_placer.set("%s_enabled" % prefix, ctrl.enabled.button_pressed)
			random_placer.set("%s_weight" % prefix, float(ctrl.weight.value))


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
		ctrl.enabled.button_pressed = cfg.get_value("enabled", prefix, true)
		ctrl.weight.value = cfg.get_value("weight", prefix, 1.0)


# ----------------------------------------------------------------------------
# GUI 构建
# ----------------------------------------------------------------------------
func _build_gui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_add_title(root, "Data Capture Control")

	# 输出目录
	var dir_row := HBoxContainer.new()
	root.add_child(dir_row)
	var dir_btn := Button.new()
	dir_btn.text = "Output Dir…"
	dir_btn.pressed.connect(_open_dir_dialog)
	dir_row.add_child(dir_btn)
	_output_dir_value = Label.new()
	_output_dir_value.text = _output_dir
	_output_dir_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_output_dir_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_output_dir_value.custom_minimum_size = Vector2(80, 0)
	dir_row.add_child(_output_dir_value)

	# 桌子形状
	_table_option = OptionButton.new()
	_table_option.add_item("Square", 0)
	_table_option.add_item("Disc", 1)
	_table_option.item_selected.connect(_on_table_shape_selected)
	_add_labeled_row(root, "Table Shape", _table_option)

	# 物品数量范围
	var count_row := HBoxContainer.new()
	_count_min = _make_spin(1, 999, 1, 3)
	_count_max = _make_spin(1, 999, 1, 7)
	count_row.add_child(_label("Min"))
	count_row.add_child(_count_min)
	count_row.add_child(_label("Max"))
	count_row.add_child(_count_max)
	_add_labeled_row(root, "Item Count", count_row)

	# 保存间隔
	_interval_spin = _make_spin(1, 600, 1, 30)
	_add_labeled_row(root, "Save Interval", _interval_spin)

	# 开关
	_save_enabled_check = _make_check("Enable Saving (live)", false, _on_save_enabled_toggled)
	root.add_child(_save_enabled_check)
	_save_depth_check = _make_check("Save Depth", false)
	root.add_child(_save_depth_check)
	_show_bbox_check = _make_check("Show BBox Preview", true, _on_show_bbox_toggled)
	root.add_child(_show_bbox_check)
	_rotate_light_check = _make_check("Enable Rotate Light", true, _on_rotate_light_toggled)
	root.add_child(_rotate_light_check)

	# 类别配置（折叠分组；整窗已有滚动，无需内嵌滚动）
	_add_title(root, "Categories")
	var cat_box := VBoxContainer.new()
	cat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(cat_box)
	_build_category_group(cat_box, "Official Categories", OFFICIAL_CATEGORIES)
	_build_category_group(cat_box, "Unknown Sub-categories", UNKNOWN_CATEGORIES)

	# 按钮
	var btn_row := HBoxContainer.new()
	root.add_child(btn_row)
	_start_btn = Button.new()
	_start_btn.text = "Start"
	_start_btn.pressed.connect(_on_start_pressed)
	btn_row.add_child(_start_btn)
	_stop_btn = Button.new()
	_stop_btn.text = "Stop"
	_stop_btn.pressed.connect(_on_stop_pressed)
	btn_row.add_child(_stop_btn)
	var save_cfg_btn := Button.new()
	save_cfg_btn.text = "Save Config"
	save_cfg_btn.pressed.connect(_on_save_config_pressed)
	btn_row.add_child(save_cfg_btn)

	# 状态
	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(_status_label)


func _build_category_group(parent: VBoxContainer, title: String, categories: Array) -> void:
	# 用可折叠的 CheckButton 作为分组标题控制展开/收起
	var header := CheckButton.new()
	header.text = title
	header.button_pressed = true
	parent.add_child(header)
	var group_box := VBoxContainer.new()
	parent.add_child(group_box)
	header.toggled.connect(func(pressed): group_box.visible = pressed)

	for entry in categories:
		var disp: String = entry[0]
		var prefix: String = entry[1]
		var row := HBoxContainer.new()
		group_box.add_child(row)
		var enabled := CheckBox.new()
		enabled.text = disp
		enabled.button_pressed = true
		enabled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(enabled)
		var weight := _make_spin(0.0, 10.0, 0.1, 1.0)
		row.add_child(weight)
		_category_controls[prefix] = {"enabled": enabled, "weight": weight}


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


# ----------------------------------------------------------------------------
# GUI 小工具
# ----------------------------------------------------------------------------
func _add_title(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)


func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _add_labeled_row(parent: Control, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := _label(text)
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


func _make_spin(min_v: float, max_v: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = value
	return spin


func _make_check(text: String, pressed: bool, on_toggled: Callable = Callable()) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = pressed
	if on_toggled.is_valid():
		check.toggled.connect(on_toggled)
	return check
