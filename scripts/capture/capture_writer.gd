extends RefCounted
class_name CaptureWriter


static func capture_viewport_image(viewport: Viewport) -> Image:
	var texture := viewport.get_texture()
	return texture.get_image()


static func save_rgb_jpg(image: Image, path: String, quality: float = 0.6) -> void:
	image.save_jpg(path, quality)


# 把深度 viewport 的 RGB8 图像（R=毫米高字节, G=低字节）还原为单通道
# 16-bit 灰度 PNG（像素值=毫米），格式与 OpenNI 深度相机输出一致。
static func save_depth_gray16(depth_image: Image, path: String) -> void:
	if depth_image.get_format() != Image.FORMAT_RGB8:
		depth_image.convert(Image.FORMAT_RGB8)
	var width := depth_image.get_width()
	var height := depth_image.get_height()
	var data := depth_image.get_data()  # RGB8: 每像素 3 字节
	var samples := PackedInt32Array()
	samples.resize(width * height)
	var src := 0
	for i in range(width * height):
		# R=高字节, G=低字节 -> 毫米
		samples[i] = (data[src] << 8) | data[src + 1]
		src += 3
	var err := DepthPng16.save_gray16(path, samples, width, height)
	if err != OK:
		push_error("深度图 16-bit PNG 保存失败: %s (err=%d)" % [path, err])


static func save_labels(path: String, viewport_size: Vector2i, labels: Array) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("标签文件保存失败: %s" % path)
		return

	for label in labels:
		var cls = label["class"]
		var bbox := _xyxy2cxywh(label["bbox"])
		file.store_line("{0} {1} {2} {3} {4}".format([
			cls,
			bbox[0] / viewport_size.x,
			bbox[1] / viewport_size.y,
			bbox[2] / viewport_size.x,
			bbox[3] / viewport_size.y,
		]))

	file.close()


static func save_classes(session_path: String, class_map: Dictionary) -> void:
	var file := FileAccess.open(session_path.path_join("classes.txt"), FileAccess.WRITE)
	if file == null:
		push_error("classes.txt 保存失败: %s" % session_path)
		return

	var unknown_id: int = class_map["Unknown"]
	# 按类别 ID 顺序取每个 ID 的规范名称；Unknown 及其下属子类别（值都等于
	# unknown_id）不写入，避免子类别把标签文件行号打乱。
	var id_to_name := {}
	for key in class_map.keys():
		var id: int = class_map[key]
		if id == unknown_id:
			continue
		if not id_to_name.has(id):
			id_to_name[id] = key
	var ids := id_to_name.keys()
	ids.sort()
	for id in ids:
		file.store_line(id_to_name[id])

	file.close()


static func _xyxy2cxywh(xyxy: Variant) -> Array:
	var x1: float = xyxy[0]
	var y1: float = xyxy[1]
	var x2: float = xyxy[2]
	var y2: float = xyxy[3]

	var center_x := (x1 + x2) / 2.0
	var center_y := (y1 + y2) / 2.0
	var width := x2 - x1
	var height := y2 - y1

	return [center_x, center_y, width, height]
