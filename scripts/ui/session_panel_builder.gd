extends RefCounted
class_name SessionPanelBuilder

const COLOR_PRIMARY := Color("#1677ff")
const COLOR_PRIMARY_HOVER := Color("#4096ff")
const COLOR_PRIMARY_PRESSED := Color("#0958d9")
const COLOR_DANGER := Color("#ff4d4f")
const COLOR_DANGER_HOVER := Color("#ff7875")
const COLOR_DANGER_PRESSED := Color("#d9363e")
const COLOR_WHITE := Color("#ffffff")
const COLOR_BORDER := Color("#d9d9d9")
const COLOR_PANEL := Color("#ffffff")
const COLOR_PANEL_ALT := Color("#fafafa")


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

	var layout := VBoxContainer.new()
	layout.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 12)
	parent.add_child(layout)

	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(tabs)

	var settings_scroll := _make_tab_scroll("Settings")
	tabs.add_child(settings_scroll)
	var settings_root := _make_tab_root()
	settings_scroll.add_child(settings_root)

	var categories_scroll := _make_tab_scroll("Categories")
	tabs.add_child(categories_scroll)
	var categories_root := _make_tab_root()
	categories_scroll.add_child(categories_root)

	_add_title(settings_root, "Data Capture Control", "Configure capture session output and runtime options.")

	var capture_card := _add_card(settings_root)
	var dir_row := HBoxContainer.new()
	capture_card.add_child(dir_row)
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
	_add_labeled_row(capture_card, "Table Shape", table_option)
	controls["table_option"] = table_option

	var count_row := HBoxContainer.new()
	var count_min := _make_spin(1, 999, 1, 3)
	var count_max := _make_spin(1, 999, 1, 7)
	count_row.add_child(_label("Min"))
	count_row.add_child(count_min)
	count_row.add_child(_label("Max"))
	count_row.add_child(count_max)
	_add_labeled_row(capture_card, "Item Count", count_row)
	controls["count_min"] = count_min
	controls["count_max"] = count_max

	var distractor_enabled_check := _make_check("Enable Table Distractors", true)
	capture_card.add_child(distractor_enabled_check)
	controls["distractor_enabled_check"] = distractor_enabled_check

	var distractor_count_row := HBoxContainer.new()
	var distractor_count_min := _make_spin(0, 99, 1, 4)
	var distractor_count_max := _make_spin(0, 99, 1, 8)
	distractor_count_row.add_child(_label("Min"))
	distractor_count_row.add_child(distractor_count_min)
	distractor_count_row.add_child(_label("Max"))
	distractor_count_row.add_child(distractor_count_max)
	_add_labeled_row(capture_card, "Distractor Count", distractor_count_row)
	controls["distractor_count_min"] = distractor_count_min
	controls["distractor_count_max"] = distractor_count_max

	var interval_spin := _make_spin(1, 600, 1, 30)
	_add_labeled_row(capture_card, "Save Interval", interval_spin)
	controls["interval_spin"] = interval_spin

	var toggles_card := _add_card(settings_root)
	var save_enabled_check := _make_check("Enable Saving (live)", false, callbacks["save_enabled_toggled"])
	toggles_card.add_child(save_enabled_check)
	controls["save_enabled_check"] = save_enabled_check

	var save_depth_check := _make_check("Save Depth", false)
	toggles_card.add_child(save_depth_check)
	controls["save_depth_check"] = save_depth_check

	var show_bbox_check := _make_check("Show BBox Preview", true, callbacks["show_bbox_toggled"])
	toggles_card.add_child(show_bbox_check)
	controls["show_bbox_check"] = show_bbox_check

	var rotate_light_check := _make_check("Enable Rotate Light", true, callbacks["rotate_light_toggled"])
	toggles_card.add_child(rotate_light_check)
	controls["rotate_light_check"] = rotate_light_check

	_add_title(categories_root, "Categories", "Enable classes and tune sampling weights.")
	var cat_box := _add_card(categories_root)
	var category_controls: Dictionary = controls["category_controls"]
	if object_catalog != null:
		_build_category_group(cat_box, "Official Categories", object_catalog.get_official_categories(), category_controls)
		_build_category_group(cat_box, "Unknown Sub-categories", object_catalog.get_unknown_categories(), category_controls)
	else:
		var missing_catalog := Label.new()
		missing_catalog.text = "Object catalog is not configured."
		cat_box.add_child(missing_catalog)

	var footer := _add_card(layout)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	footer.add_child(btn_row)
	var start_btn := Button.new()
	start_btn.text = "Start"
	start_btn.custom_minimum_size = Vector2(0, 36)
	start_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_primary_button(start_btn)
	start_btn.pressed.connect(callbacks["start"])
	btn_row.add_child(start_btn)
	controls["start_btn"] = start_btn

	var stop_btn := Button.new()
	stop_btn.text = "Stop"
	stop_btn.custom_minimum_size = Vector2(0, 36)
	stop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_danger_button(stop_btn)
	stop_btn.pressed.connect(callbacks["stop"])
	btn_row.add_child(stop_btn)
	controls["stop_btn"] = stop_btn

	var save_cfg_btn := Button.new()
	save_cfg_btn.text = "Save Config"
	save_cfg_btn.custom_minimum_size = Vector2(0, 36)
	save_cfg_btn.pressed.connect(callbacks["save_config"])
	btn_row.add_child(save_cfg_btn)

	var status_label := Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.add_theme_color_override("font_color", Color("#6b7280"))
	footer.add_child(status_label)
	controls["status_label"] = status_label

	return controls



static func _make_tab_scroll(title: String) -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	return scroll


static func _make_tab_root() -> VBoxContainer:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return root

static func _build_category_group(
	parent: VBoxContainer,
	title: String,
	categories: Array[ObjectCategory],
	category_controls: Dictionary
) -> void:
	var card := _add_card(parent, 0)
	var header := Button.new()
	header.toggle_mode = true
	header.button_pressed = true
	header.text = "▾ " + title
	header.custom_minimum_size = Vector2(0, 30)
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_apply_section_header_button(header)
	card.add_child(header)
	var group_box := VBoxContainer.new()
	group_box.add_theme_constant_override("separation", 6)
	card.add_child(group_box)
	header.toggled.connect(func(pressed: bool):
		group_box.visible = pressed
		header.text = ("▾ " if pressed else "▸ ") + title
	)

	for category in categories:
		if category == null:
			continue
		var key := str(category.key)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		group_box.add_child(row)
		var enabled := CheckBox.new()
		enabled.text = str(category.display_name)
		enabled.button_pressed = category.enabled
		enabled.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(enabled)
		var weight := _make_spin(0.0, 10.0, 0.1, category.weight)
		weight.custom_minimum_size = Vector2(82, 0)
		row.add_child(weight)
		category_controls[key] = {"enabled": enabled, "weight": weight, "category": category}


static func _add_title(parent: Control, text: String, subtitle: String = "") -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", Color("#111827"))
	box.add_child(label)
	if not subtitle.is_empty():
		var subtitle_label := Label.new()
		subtitle_label.text = subtitle
		subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		subtitle_label.add_theme_color_override("font_color", Color("#6b7280"))
		box.add_child(subtitle_label)


static func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


static func _add_labeled_row(parent: Control, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := _label(text)
	label.custom_minimum_size = Vector2(96, 0)
	label.add_theme_color_override("font_color", Color("#4b5563"))
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


static func _add_card(parent: Control, margin: int = 12) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)

	var margins := MarginContainer.new()
	margins.add_theme_constant_override("margin_left", margin)
	margins.add_theme_constant_override("margin_top", margin)
	margins.add_theme_constant_override("margin_right", margin)
	margins.add_theme_constant_override("margin_bottom", margin)
	panel.add_child(margins)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margins.add_child(box)
	return box


static func _apply_primary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(COLOR_PRIMARY))
	button.add_theme_stylebox_override("hover", _button_box(COLOR_PRIMARY_HOVER))
	button.add_theme_stylebox_override("pressed", _button_box(COLOR_PRIMARY_PRESSED))
	button.add_theme_stylebox_override("hover_pressed", _button_box(COLOR_PRIMARY_PRESSED))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#91caff")))
	button.add_theme_color_override("font_color", COLOR_WHITE)
	button.add_theme_color_override("font_hover_color", COLOR_WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	button.add_theme_color_override("font_hover_pressed_color", COLOR_WHITE)
	button.add_theme_color_override("font_disabled_color", COLOR_WHITE)


static func _apply_danger_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button_box(COLOR_DANGER))
	button.add_theme_stylebox_override("hover", _button_box(COLOR_DANGER_HOVER))
	button.add_theme_stylebox_override("pressed", _button_box(COLOR_DANGER_PRESSED))
	button.add_theme_stylebox_override("hover_pressed", _button_box(COLOR_DANGER_PRESSED))
	button.add_theme_stylebox_override("disabled", _button_box(Color("#ffa39e")))
	button.add_theme_color_override("font_color", COLOR_WHITE)
	button.add_theme_color_override("font_hover_color", COLOR_WHITE)
	button.add_theme_color_override("font_pressed_color", COLOR_WHITE)
	button.add_theme_color_override("font_hover_pressed_color", COLOR_WHITE)
	button.add_theme_color_override("font_disabled_color", COLOR_WHITE)


static func _apply_section_header_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _section_header_box(COLOR_PANEL_ALT, COLOR_BORDER))
	button.add_theme_stylebox_override("hover", _section_header_box(Color("#f0f6ff"), COLOR_PRIMARY_HOVER))
	button.add_theme_stylebox_override("pressed", _section_header_box(Color("#e6f4ff"), COLOR_PRIMARY))
	button.add_theme_color_override("font_color", Color("#1f2329"))
	button.add_theme_color_override("font_hover_color", Color("#1f2329"))
	button.add_theme_color_override("font_pressed_color", Color("#1f2329"))


static func _button_box(color: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = color
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box


static func _section_header_box(bg: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(6)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
