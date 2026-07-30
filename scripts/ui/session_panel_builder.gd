extends RefCounted
class_name SessionPanelBuilder


static func build(
	parent: Control,
	output_dir: String,
	object_catalog: ObjectCatalog,
	callbacks: Dictionary
) -> Dictionary:
	parent.set_anchors_preset(Control.PRESET_FULL_RECT)

	var controls := {
		"category_controls": {},
	}

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	parent.add_child(scroll)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(root)

	_add_title(root, "Data Capture Control")

	var dir_row := HBoxContainer.new()
	root.add_child(dir_row)
	var dir_btn := Button.new()
	dir_btn.text = "Output Dir..."
	dir_btn.pressed.connect(callbacks["open_dir"])
	dir_row.add_child(dir_btn)
	var output_dir_value := Label.new()
	output_dir_value.text = output_dir
	output_dir_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	output_dir_value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	output_dir_value.custom_minimum_size = Vector2(80, 0)
	dir_row.add_child(output_dir_value)
	controls["output_dir_value"] = output_dir_value

	var table_option := OptionButton.new()
	table_option.add_item("Square", 0)
	table_option.add_item("Disc", 1)
	table_option.item_selected.connect(callbacks["table_shape_selected"])
	_add_labeled_row(root, "Table Shape", table_option)
	controls["table_option"] = table_option

	var count_row := HBoxContainer.new()
	var count_min := _make_spin(1, 999, 1, 3)
	var count_max := _make_spin(1, 999, 1, 7)
	count_row.add_child(_label("Min"))
	count_row.add_child(count_min)
	count_row.add_child(_label("Max"))
	count_row.add_child(count_max)
	_add_labeled_row(root, "Item Count", count_row)
	controls["count_min"] = count_min
	controls["count_max"] = count_max

	var interval_spin := _make_spin(1, 600, 1, 30)
	_add_labeled_row(root, "Save Interval", interval_spin)
	controls["interval_spin"] = interval_spin

	var save_enabled_check := _make_check("Enable Saving (live)", false, callbacks["save_enabled_toggled"])
	root.add_child(save_enabled_check)
	controls["save_enabled_check"] = save_enabled_check

	var save_depth_check := _make_check("Save Depth", false)
	root.add_child(save_depth_check)
	controls["save_depth_check"] = save_depth_check

	var show_bbox_check := _make_check("Show BBox Preview", true, callbacks["show_bbox_toggled"])
	root.add_child(show_bbox_check)
	controls["show_bbox_check"] = show_bbox_check

	var rotate_light_check := _make_check("Enable Rotate Light", true, callbacks["rotate_light_toggled"])
	root.add_child(rotate_light_check)
	controls["rotate_light_check"] = rotate_light_check

	_add_title(root, "Categories")
	var cat_box := VBoxContainer.new()
	cat_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.add_child(cat_box)
	var category_controls: Dictionary = controls["category_controls"]
	if object_catalog != null:
		_build_category_group(cat_box, "Official Categories", object_catalog.get_official_categories(), category_controls)
		_build_category_group(cat_box, "Unknown Sub-categories", object_catalog.get_unknown_categories(), category_controls)
	else:
		var missing_catalog := Label.new()
		missing_catalog.text = "Object catalog is not configured."
		cat_box.add_child(missing_catalog)

	var btn_row := HBoxContainer.new()
	root.add_child(btn_row)
	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.pressed.connect(callbacks["start"])
	btn_row.add_child(start_btn)
	controls["start_btn"] = start_btn

	var stop_btn := Button.new()
	stop_btn.text = "Stop"
	stop_btn.pressed.connect(callbacks["stop"])
	btn_row.add_child(stop_btn)
	controls["stop_btn"] = stop_btn

	var save_cfg_btn := Button.new()
	save_cfg_btn.text = "Save Config"
	save_cfg_btn.pressed.connect(callbacks["save_config"])
	btn_row.add_child(save_cfg_btn)

	var status_label := Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(status_label)
	controls["status_label"] = status_label

	return controls


static func _build_category_group(
	parent: VBoxContainer,
	title: String,
	categories: Array[ObjectCategory],
	category_controls: Dictionary
) -> void:
	var header := CheckButton.new()
	header.text = title
	header.button_pressed = true
	parent.add_child(header)
	var group_box := VBoxContainer.new()
	parent.add_child(group_box)
	header.toggled.connect(func(pressed: bool): group_box.visible = pressed)

	for category in categories:
		if category == null:
			continue
		var key := str(category.key)
		var row := HBoxContainer.new()
		group_box.add_child(row)
		var enabled := CheckBox.new()
		enabled.text = str(category.display_name)
		enabled.button_pressed = category.enabled
		enabled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(enabled)
		var weight := _make_spin(0.0, 10.0, 0.1, category.weight)
		row.add_child(weight)
		category_controls[key] = {"enabled": enabled, "weight": weight, "category": category}


static func _add_title(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	parent.add_child(label)


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


static func _add_labeled_row(parent: Control, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := _label(text)
	label.custom_minimum_size = Vector2(90, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	parent.add_child(row)


static func _make_spin(min_v: float, max_v: float, step: float, value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_v
	spin.max_value = max_v
	spin.step = step
	spin.value = value
	return spin


static func _make_check(text: String, pressed: bool, on_toggled: Callable = Callable()) -> CheckBox:
	var check := CheckBox.new()
	check.text = text
	check.button_pressed = pressed
	if on_toggled.is_valid():
		check.toggled.connect(on_toggled)
	return check
