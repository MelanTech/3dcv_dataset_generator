extends RefCounted
class_name CaptureViewportRig

var viewport: SubViewport
var camera: Camera3D
var post_process: CanvasLayer
var camera_augmentation: CanvasLayer


func setup(
	owner: Node,
	size: Vector2i,
	world: World3D,
	source_post_process: CanvasLayer,
	source_camera_augmenter: Node = null
) -> void:
	viewport = SubViewport.new()
	viewport.name = "CleanCaptureViewport"
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	viewport.world_3d = world
	viewport.size = size
	owner.add_child(viewport)

	camera = Camera3D.new()
	camera.name = "CleanCaptureCamera"
	viewport.add_child(camera)

	if source_post_process != null:
		post_process = CanvasLayer.new()
		post_process.name = "CleanCapturePostProcess"
		post_process.set_script(load("res://addons/post_processing/node/post_process.gd"))
		post_process.set("configuration", source_post_process.get("configuration"))
		post_process.set("dynamically_update", source_post_process.get("dynamically_update"))
		post_process.layer = source_post_process.layer
		post_process.custom_viewport = viewport
		viewport.add_child(post_process)

	if source_camera_augmenter != null and source_camera_augmenter.has_method("create_effect_layer"):
		camera_augmentation = source_camera_augmenter.call("create_effect_layer", viewport) as CanvasLayer
		if camera_augmentation != null:
			viewport.add_child(camera_augmentation)


func prepare(size: Vector2i, world: World3D, source_camera: Camera3D) -> void:
	if viewport == null:
		return
	viewport.size = size
	viewport.world_3d = world
	_sync_camera(source_camera)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func _sync_camera(source_camera: Camera3D) -> void:
	if source_camera == null or camera == null:
		return

	camera.global_transform = source_camera.global_transform
	camera.keep_aspect = source_camera.keep_aspect
	camera.cull_mask = source_camera.cull_mask
	camera.environment = source_camera.environment
	camera.attributes = source_camera.attributes
	camera.doppler_tracking = source_camera.doppler_tracking
	camera.projection = source_camera.projection
	camera.current = true

	match source_camera.projection:
		Camera3D.PROJECTION_PERSPECTIVE:
			camera.fov = source_camera.fov
			camera.near = source_camera.near
			camera.far = source_camera.far
		Camera3D.PROJECTION_ORTHOGONAL:
			camera.size = source_camera.size
			camera.near = source_camera.near
			camera.far = source_camera.far
		Camera3D.PROJECTION_FRUSTUM:
			camera.size = source_camera.size
			camera.frustum_offset = source_camera.frustum_offset
			camera.near = source_camera.near
			camera.far = source_camera.far
