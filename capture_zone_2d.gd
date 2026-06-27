extends Area2D
class_name CaptureZone2D

## Provides a bounding zone that captures a PNG image of its content.
## Triggered by setting recapture=true and pressing Play in the Godot editor.
## The game must be running for the capture to work (SubViewport rendering requires
## an active render loop).

## When true, triggers a capture on the next game start. Resets to false after capture.
@export var recapture: bool = false

## The directory where the captured image will be saved.
@export_dir var output_directory: String = "res://export/capture/"

## Base filename prefix for captured images (without extension).
## Captured files are named <filename>_<shape_name>.png.
## If empty, the node name is used as the prefix.
@export var filename: String = "capture_zone_image"

## Scenario name written into the metadata JSON.
@export var scenario: String = ""

func _ready() -> void:
	if recapture:
		_run_capture()

## Captures an image of the content within a specific child collision node.
## Returns an Image object or null if failed.
func capture_content(child: Node2D = null) -> Image:
	var global_aabb: Rect2

	if child:
		var collision_shape := child as CollisionShape2D
		if collision_shape and collision_shape.shape:
			var child_rect: Rect2 = collision_shape.shape.get_rect()
			global_aabb = collision_shape.global_transform * child_rect
		else:
			push_warning("CaptureZone2D: Provided node is not a supported collision shape.")
			return null
	else:
		push_warning("CaptureZone2D: No child node provided.")
		return null

	if global_aabb.size.x <= 0 or global_aabb.size.y <= 0:
		push_warning("CaptureZone2D: Capture area is empty or invalid.")
		return null

	print("[CaptureZone2D] capture_content: AABB pos=%s size=%s" % [global_aabb.position, global_aabb.size])

	var viewport := get_viewport()
	if not viewport:
		push_warning("CaptureZone2D: No viewport available.")
		return null

	var sub_viewport := SubViewport.new()
	add_child(sub_viewport)

	sub_viewport.size = global_aabb.size as Vector2i
	sub_viewport.transparent_bg = true
	# Defer rendering until the camera is positioned to avoid a blank frame.
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sub_viewport.world_2d = viewport.world_2d

	print("[CaptureZone2D] capture_content: SubViewport size=%s" % [sub_viewport.size])

	var camera := Camera2D.new()
	sub_viewport.add_child(camera)
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position = global_aabb.position
	camera.make_current()

	print("[CaptureZone2D] capture_content: Camera2D position=%s" % [camera.position])

	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img = sub_viewport.get_texture().get_image()
	print("[CaptureZone2D] capture_content: Image size=%s" % [img.get_size() if img else Vector2i.ZERO])

	remove_child(sub_viewport)
	sub_viewport.queue_free()

	return img

## Captures all child CollisionShape2D zones and exports PNG + metadata JSON.
## Runs when the game starts with recapture=true; resets the flag when done.
func _run_capture() -> void:
	recapture = false
	print("[CaptureZone2D] _run_capture: started for '%s', output='%s'" % [name, output_directory])

	var metadata: Dictionary = {}

	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_recursive_absolute(output_directory)

	for child in get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape and collision_shape.shape:
			var base: String = filename if filename != "" else name
			var shape_filename := base + "_" + collision_shape.name
			var save_path := output_directory.path_join(shape_filename + ".png")
			print("[CaptureZone2D] _run_capture: processing child '%s' -> '%s'" % [collision_shape.name, save_path])

			var img := await capture_content(collision_shape)
			if img:
				var err := img.save_png(save_path)
				if err == OK:
					print("[CaptureZone2D] _run_capture: saved '%s'" % [save_path])

					var child_rect: Rect2 = collision_shape.shape.get_rect()
					var global_aabb: Rect2 = collision_shape.global_transform * child_rect
					var center := global_aabb.get_center()

					var key := name + "_" + child.name + "_Top"
					metadata[key] = {
						"filename": shape_filename + ".png",
						"cubemap_face": "Top",
						"global_position": {
							"x": center.x,
							"y": center.y,
							"z": 0.0
						},
						"global_quaternion": {
							"x": 0.0,
							"y": 0.0,
							"z": sin(global_rotation / 2.0),
							"w": cos(global_rotation / 2.0)
						},
						"size": {
							"x": global_aabb.size.x,
							"y": global_aabb.size.y,
							"z": 0.0
						}
					}
				else:
					push_error("CaptureZone2D: Failed to save '%s' (err=%d)" % [save_path, err])

	if metadata.size() > 0:
		var meta_path = output_directory.path_join(name + "_metadata.json")
		var meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
		if meta_file:
			meta_file.store_string(JSON.stringify(metadata, "\t"))
			meta_file.close()
			print("[CaptureZone2D] _run_capture: metadata saved to '%s'" % [meta_path])
	else:
		push_warning("CaptureZone2D: No valid collision shapes found or all captures failed.")
