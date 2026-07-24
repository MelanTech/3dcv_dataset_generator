extends Node2D

@export var data_generator: Node

func _process(delta: float) -> void:
	queue_redraw()
	
func _draw() -> void:
	var labels = data_generator.labels
	if not labels.is_empty():
		for label in labels:
			var xywh = _xyxy2xywh(label['bbox'])
			var rect = Rect2(xywh[0], xywh[1], xywh[2], xywh[3])
			draw_rect(rect, Color.GREEN, false)

func _xyxy2xywh(bbox: Variant) -> Array:
	var x1 = bbox[0]
	var y1 = bbox[1]
	var x2 = bbox[2]
	var y2 = bbox[3]
	
	var w = x2 - x1
	var h = y2 - y1
	
	return [x1, y1, w, h]
