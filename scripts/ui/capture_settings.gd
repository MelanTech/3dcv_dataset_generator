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
var visibility_threshold := 20
var occlusion_sample_mode := 1
var occlusion_grid_sample_count := 10
var drop_below_table_threshold := 0.35
var debug_occlusion := false
var camera_rotation_speed := 90.0
var camera_transition_duration := 1.0
var camera_distance_min := 15.0
var camera_distance_max := 20.0
var camera_height_min := 5.0
var camera_height_max := 15.0
var camera_rotation_x_min := -8.0
var camera_rotation_x_max := 8.0
var camera_rotation_y_min := -10.0
var camera_rotation_y_max := 10.0
var camera_rotation_z_min := -5.0
var camera_rotation_z_max := 5.0
var camera_perturb_enabled := true
var camera_change_time_min := 1.0
var camera_change_time_max := 3.0
var camera_distortion_enabled := true
var distortion_delta_min := -0.06
var distortion_delta_max := 0.06
var white_balance_enabled := true
var warm_cool_min := -0.08
var warm_cool_max := 0.08
var green_magenta_min := -0.04
var green_magenta_max := 0.04
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
	settings.visibility_threshold = int(controls["visibility_threshold"].value)
	settings.occlusion_sample_mode = controls["occlusion_sample_mode"].selected
	settings.occlusion_grid_sample_count = int(controls["occlusion_grid_sample_count"].value)
	settings.drop_below_table_threshold = float(controls["drop_below_table_threshold"].value)
	settings.debug_occlusion = controls["debug_occlusion_check"].button_pressed
	settings.camera_rotation_speed = float(controls["camera_rotation_speed"].value)
	settings.camera_transition_duration = float(controls["camera_transition_duration"].value)
	settings.camera_distance_min = float(controls["camera_distance_min"].value)
	settings.camera_distance_max = float(controls["camera_distance_max"].value)
	settings.camera_height_min = float(controls["camera_height_min"].value)
	settings.camera_height_max = float(controls["camera_height_max"].value)
	settings.camera_rotation_x_min = float(controls["camera_rotation_x_min"].value)
	settings.camera_rotation_x_max = float(controls["camera_rotation_x_max"].value)
	settings.camera_rotation_y_min = float(controls["camera_rotation_y_min"].value)
	settings.camera_rotation_y_max = float(controls["camera_rotation_y_max"].value)
	settings.camera_rotation_z_min = float(controls["camera_rotation_z_min"].value)
	settings.camera_rotation_z_max = float(controls["camera_rotation_z_max"].value)
	settings.camera_perturb_enabled = controls["camera_perturb_enabled_check"].button_pressed
	settings.camera_change_time_min = float(controls["camera_change_time_min"].value)
	settings.camera_change_time_max = float(controls["camera_change_time_max"].value)
	settings.camera_distortion_enabled = controls["camera_distortion_enabled_check"].button_pressed
	settings.distortion_delta_min = float(controls["distortion_delta_min"].value)
	settings.distortion_delta_max = float(controls["distortion_delta_max"].value)
	settings.white_balance_enabled = controls["white_balance_enabled_check"].button_pressed
	settings.warm_cool_min = float(controls["warm_cool_min"].value)
	settings.warm_cool_max = float(controls["warm_cool_max"].value)
	settings.green_magenta_min = float(controls["green_magenta_min"].value)
	settings.green_magenta_max = float(controls["green_magenta_max"].value)

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
	settings.visibility_threshold = cfg.get_value("label_filtering", "visibility_threshold", settings.visibility_threshold)
	settings.occlusion_sample_mode = cfg.get_value("label_filtering", "occlusion_sample_mode", settings.occlusion_sample_mode)
	settings.occlusion_grid_sample_count = cfg.get_value("label_filtering", "occlusion_grid_sample_count", settings.occlusion_grid_sample_count)
	settings.drop_below_table_threshold = cfg.get_value("label_filtering", "drop_below_table_threshold", settings.drop_below_table_threshold)
	settings.debug_occlusion = cfg.get_value("label_filtering", "debug_occlusion", settings.debug_occlusion)
	settings.camera_rotation_speed = cfg.get_value("camera_motion", "rotation_speed", settings.camera_rotation_speed)
	settings.camera_transition_duration = cfg.get_value("camera_motion", "transition_duration", settings.camera_transition_duration)
	settings.camera_distance_min = cfg.get_value("camera_motion", "distance_min", settings.camera_distance_min)
	settings.camera_distance_max = cfg.get_value("camera_motion", "distance_max", settings.camera_distance_max)
	settings.camera_height_min = cfg.get_value("camera_motion", "height_min", settings.camera_height_min)
	settings.camera_height_max = cfg.get_value("camera_motion", "height_max", settings.camera_height_max)
	settings.camera_rotation_x_min = cfg.get_value("camera_motion", "rotation_x_min", settings.camera_rotation_x_min)
	settings.camera_rotation_x_max = cfg.get_value("camera_motion", "rotation_x_max", settings.camera_rotation_x_max)
	settings.camera_rotation_y_min = cfg.get_value("camera_motion", "rotation_y_min", settings.camera_rotation_y_min)
	settings.camera_rotation_y_max = cfg.get_value("camera_motion", "rotation_y_max", settings.camera_rotation_y_max)
	settings.camera_rotation_z_min = cfg.get_value("camera_motion", "rotation_z_min", settings.camera_rotation_z_min)
	settings.camera_rotation_z_max = cfg.get_value("camera_motion", "rotation_z_max", settings.camera_rotation_z_max)
	settings.camera_perturb_enabled = cfg.get_value("camera", "camera_perturb_enabled", settings.camera_perturb_enabled)
	settings.camera_change_time_min = cfg.get_value("camera", "camera_change_time_min", settings.camera_change_time_min)
	settings.camera_change_time_max = cfg.get_value("camera", "camera_change_time_max", settings.camera_change_time_max)
	settings.camera_distortion_enabled = cfg.get_value("camera", "camera_distortion_enabled", settings.camera_distortion_enabled)
	settings.distortion_delta_min = cfg.get_value("camera", "distortion_delta_min", settings.distortion_delta_min)
	settings.distortion_delta_max = cfg.get_value("camera", "distortion_delta_max", settings.distortion_delta_max)
	settings.white_balance_enabled = cfg.get_value("camera", "white_balance_enabled", settings.white_balance_enabled)
	settings.warm_cool_min = cfg.get_value("camera", "warm_cool_min", settings.warm_cool_min)
	settings.warm_cool_max = cfg.get_value("camera", "warm_cool_max", settings.warm_cool_max)
	settings.green_magenta_min = cfg.get_value("camera", "green_magenta_min", settings.green_magenta_min)
	settings.green_magenta_max = cfg.get_value("camera", "green_magenta_max", settings.green_magenta_max)

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
	cfg.set_value("label_filtering", "visibility_threshold", visibility_threshold)
	cfg.set_value("label_filtering", "occlusion_sample_mode", occlusion_sample_mode)
	cfg.set_value("label_filtering", "occlusion_grid_sample_count", occlusion_grid_sample_count)
	cfg.set_value("label_filtering", "drop_below_table_threshold", drop_below_table_threshold)
	cfg.set_value("label_filtering", "debug_occlusion", debug_occlusion)
	cfg.set_value("camera_motion", "rotation_speed", camera_rotation_speed)
	cfg.set_value("camera_motion", "transition_duration", camera_transition_duration)
	cfg.set_value("camera_motion", "distance_min", camera_distance_min)
	cfg.set_value("camera_motion", "distance_max", camera_distance_max)
	cfg.set_value("camera_motion", "height_min", camera_height_min)
	cfg.set_value("camera_motion", "height_max", camera_height_max)
	cfg.set_value("camera_motion", "rotation_x_min", camera_rotation_x_min)
	cfg.set_value("camera_motion", "rotation_x_max", camera_rotation_x_max)
	cfg.set_value("camera_motion", "rotation_y_min", camera_rotation_y_min)
	cfg.set_value("camera_motion", "rotation_y_max", camera_rotation_y_max)
	cfg.set_value("camera_motion", "rotation_z_min", camera_rotation_z_min)
	cfg.set_value("camera_motion", "rotation_z_max", camera_rotation_z_max)
	cfg.set_value("camera", "camera_perturb_enabled", camera_perturb_enabled)
	cfg.set_value("camera", "camera_change_time_min", camera_change_time_min)
	cfg.set_value("camera", "camera_change_time_max", camera_change_time_max)
	cfg.set_value("camera", "camera_distortion_enabled", camera_distortion_enabled)
	cfg.set_value("camera", "distortion_delta_min", distortion_delta_min)
	cfg.set_value("camera", "distortion_delta_max", distortion_delta_max)
	cfg.set_value("camera", "white_balance_enabled", white_balance_enabled)
	cfg.set_value("camera", "warm_cool_min", warm_cool_min)
	cfg.set_value("camera", "warm_cool_max", warm_cool_max)
	cfg.set_value("camera", "green_magenta_min", green_magenta_min)
	cfg.set_value("camera", "green_magenta_max", green_magenta_max)

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
	controls["visibility_threshold"].value = visibility_threshold
	controls["occlusion_sample_mode"].selected = occlusion_sample_mode
	controls["occlusion_grid_sample_count"].value = occlusion_grid_sample_count
	controls["drop_below_table_threshold"].value = drop_below_table_threshold
	controls["debug_occlusion_check"].button_pressed = debug_occlusion
	controls["camera_rotation_speed"].value = camera_rotation_speed
	controls["camera_transition_duration"].value = camera_transition_duration
	controls["camera_distance_min"].value = camera_distance_min
	controls["camera_distance_max"].value = camera_distance_max
	controls["camera_height_min"].value = camera_height_min
	controls["camera_height_max"].value = camera_height_max
	controls["camera_rotation_x_min"].value = camera_rotation_x_min
	controls["camera_rotation_x_max"].value = camera_rotation_x_max
	controls["camera_rotation_y_min"].value = camera_rotation_y_min
	controls["camera_rotation_y_max"].value = camera_rotation_y_max
	controls["camera_rotation_z_min"].value = camera_rotation_z_min
	controls["camera_rotation_z_max"].value = camera_rotation_z_max
	controls["camera_perturb_enabled_check"].button_pressed = camera_perturb_enabled
	controls["camera_change_time_min"].value = camera_change_time_min
	controls["camera_change_time_max"].value = camera_change_time_max
	controls["camera_distortion_enabled_check"].button_pressed = camera_distortion_enabled
	controls["distortion_delta_min"].value = distortion_delta_min
	controls["distortion_delta_max"].value = distortion_delta_max
	controls["white_balance_enabled_check"].button_pressed = white_balance_enabled
	controls["warm_cool_min"].value = warm_cool_min
	controls["warm_cool_max"].value = warm_cool_max
	controls["green_magenta_min"].value = green_magenta_min
	controls["green_magenta_max"].value = green_magenta_max

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
	copy.visibility_threshold = visibility_threshold
	copy.occlusion_sample_mode = occlusion_sample_mode
	copy.occlusion_grid_sample_count = occlusion_grid_sample_count
	copy.drop_below_table_threshold = drop_below_table_threshold
	copy.debug_occlusion = debug_occlusion
	copy.camera_rotation_speed = camera_rotation_speed
	copy.camera_transition_duration = camera_transition_duration
	copy.camera_distance_min = camera_distance_min
	copy.camera_distance_max = camera_distance_max
	copy.camera_height_min = camera_height_min
	copy.camera_height_max = camera_height_max
	copy.camera_rotation_x_min = camera_rotation_x_min
	copy.camera_rotation_x_max = camera_rotation_x_max
	copy.camera_rotation_y_min = camera_rotation_y_min
	copy.camera_rotation_y_max = camera_rotation_y_max
	copy.camera_rotation_z_min = camera_rotation_z_min
	copy.camera_rotation_z_max = camera_rotation_z_max
	copy.camera_perturb_enabled = camera_perturb_enabled
	copy.camera_change_time_min = camera_change_time_min
	copy.camera_change_time_max = camera_change_time_max
	copy.camera_distortion_enabled = camera_distortion_enabled
	copy.distortion_delta_min = distortion_delta_min
	copy.distortion_delta_max = distortion_delta_max
	copy.white_balance_enabled = white_balance_enabled
	copy.warm_cool_min = warm_cool_min
	copy.warm_cool_max = warm_cool_max
	copy.green_magenta_min = green_magenta_min
	copy.green_magenta_max = green_magenta_max
	copy.category_enabled = category_enabled.duplicate()
	copy.category_weight = category_weight.duplicate()
	return copy
