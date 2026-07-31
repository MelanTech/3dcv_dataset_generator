extends RefCounted
class_name CaptureSettings

var output_dir := ""
var count_min := 3
var count_max := 7
var distractor_enabled := true
var distractor_count_min := 4
var distractor_count_max := 8
var save_interval := 30
var save_depth := false
var save_enabled := false
var show_bbox := true
var rotate_light := true
var table_shape := 0
var category_enabled := {}
var category_weight := {}


static func from_controls(output_dir_value: String, controls: Dictionary) -> CaptureSettings:
	var settings := CaptureSettings.new()
	settings.output_dir = output_dir_value
	settings.count_min = int(controls["count_min"].value)
	settings.count_max = int(controls["count_max"].value)
	settings.distractor_enabled = controls["distractor_enabled_check"].button_pressed
	settings.distractor_count_min = int(controls["distractor_count_min"].value)
	settings.distractor_count_max = int(controls["distractor_count_max"].value)
	settings.save_interval = int(controls["interval_spin"].value)
	settings.save_depth = controls["save_depth_check"].button_pressed
	settings.save_enabled = controls["save_enabled_check"].button_pressed
	settings.show_bbox = controls["show_bbox_check"].button_pressed
	settings.rotate_light = controls["rotate_light_check"].button_pressed
	settings.table_shape = controls["table_option"].selected

	var category_controls: Dictionary = controls["category_controls"]
	for key in category_controls:
		var ctrl = category_controls[key]
		settings.category_enabled[key] = ctrl.enabled.button_pressed
		settings.category_weight[key] = float(ctrl.weight.value)

	return settings


static func load_from_file(path: String, defaults: CaptureSettings) -> CaptureSettings:
	var settings := defaults.duplicate_settings()
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return settings

	settings.output_dir = cfg.get_value("general", "output_dir", settings.output_dir)
	settings.count_min = cfg.get_value("general", "count_min", settings.count_min)
	settings.count_max = cfg.get_value("general", "count_max", settings.count_max)
	settings.distractor_enabled = cfg.get_value("general", "distractor_enabled", settings.distractor_enabled)
	settings.distractor_count_min = cfg.get_value("general", "distractor_count_min", settings.distractor_count_min)
	settings.distractor_count_max = cfg.get_value("general", "distractor_count_max", settings.distractor_count_max)
	settings.save_interval = cfg.get_value("general", "save_interval", settings.save_interval)
	settings.save_depth = cfg.get_value("general", "save_depth", settings.save_depth)
	settings.save_enabled = cfg.get_value("general", "save_enabled", settings.save_enabled)
	settings.show_bbox = cfg.get_value("general", "show_bbox", settings.show_bbox)
	settings.rotate_light = cfg.get_value("general", "rotate_light", settings.rotate_light)
	settings.table_shape = cfg.get_value("general", "table_shape", settings.table_shape)

	for key in settings.category_enabled:
		settings.category_enabled[key] = cfg.get_value("enabled", key, settings.category_enabled[key])
	for key in settings.category_weight:
		settings.category_weight[key] = cfg.get_value("weight", key, settings.category_weight[key])

	return settings


func save_to_file(path: String) -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("general", "output_dir", output_dir)
	cfg.set_value("general", "count_min", count_min)
	cfg.set_value("general", "count_max", count_max)
	cfg.set_value("general", "distractor_enabled", distractor_enabled)
	cfg.set_value("general", "distractor_count_min", distractor_count_min)
	cfg.set_value("general", "distractor_count_max", distractor_count_max)
	cfg.set_value("general", "save_interval", save_interval)
	cfg.set_value("general", "save_depth", save_depth)
	cfg.set_value("general", "save_enabled", save_enabled)
	cfg.set_value("general", "show_bbox", show_bbox)
	cfg.set_value("general", "rotate_light", rotate_light)
	cfg.set_value("general", "table_shape", table_shape)

	for key in category_enabled:
		cfg.set_value("enabled", key, category_enabled[key])
	for key in category_weight:
		cfg.set_value("weight", key, category_weight[key])

	return cfg.save(path)


func apply_to_controls(controls: Dictionary) -> void:
	controls["output_dir_value"].text = output_dir
	controls["count_min"].value = count_min
	controls["count_max"].value = count_max
	controls["distractor_enabled_check"].button_pressed = distractor_enabled
	controls["distractor_count_min"].value = distractor_count_min
	controls["distractor_count_max"].value = distractor_count_max
	controls["interval_spin"].value = save_interval
	controls["save_depth_check"].button_pressed = save_depth
	controls["save_enabled_check"].button_pressed = save_enabled
	controls["show_bbox_check"].button_pressed = show_bbox
	controls["rotate_light_check"].button_pressed = rotate_light
	controls["table_option"].selected = table_shape

	var category_controls: Dictionary = controls["category_controls"]
	for key in category_controls:
		var ctrl = category_controls[key]
		if category_enabled.has(key):
			ctrl.enabled.button_pressed = category_enabled[key]
		if category_weight.has(key):
			ctrl.weight.value = category_weight[key]


func duplicate_settings() -> CaptureSettings:
	var copy := CaptureSettings.new()
	copy.output_dir = output_dir
	copy.count_min = count_min
	copy.count_max = count_max
	copy.distractor_enabled = distractor_enabled
	copy.distractor_count_min = distractor_count_min
	copy.distractor_count_max = distractor_count_max
	copy.save_interval = save_interval
	copy.save_depth = save_depth
	copy.save_enabled = save_enabled
	copy.show_bbox = show_bbox
	copy.rotate_light = rotate_light
	copy.table_shape = table_shape
	copy.category_enabled = category_enabled.duplicate()
	copy.category_weight = category_weight.duplicate()
	return copy
