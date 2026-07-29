extends Node2D

@export var data_generator: Node
@export var realtime_refresh: bool = true
@export_range(1, 60, 1) var refresh_interval_frames: int = 1

var _frame_index := 0

func _process(delta: float) -> void:
	if visible and realtime_refresh and _frame_index % refresh_interval_frames == 0:
		if data_generator != null and data_generator.has_method("refresh_labels"):
			data_generator.refresh_labels()

	_frame_index += 1
	queue_redraw()
	
func _draw() -> void:
	if data_generator == null:
		return

	var labels = data_generator.labels
	if not labels.is_empty():
		for label in labels:
			if not label.has("bbox") or label["bbox"].size() < 4:
				continue
			var xywh = _xyxy2xywh(label['bbox'])
			var rect = Rect2(xywh[0], xywh[1], xywh[2], xywh[3])
			draw_rect(rect, Color.GREEN, false, 2.0)

func _xyxy2xywh(bbox: Variant) -> Array:
	var x1 = bbox[0]
	var y1 = bbox[1]
	var x2 = bbox[2]
	var y2 = bbox[3]
	
	var w = x2 - x1
	var h = y2 - y1
	
	return [x1, y1, w, h]
