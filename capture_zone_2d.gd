extends Area2D
class_name CaptureZone2D

## This script adds a special bounding box / script that can be applied to object.
## It is used to capture an image of their content.

## If enabled, it will capture the image of the zone's content.
@export var recapture: bool = false

## The directory where the captured image will be saved.
@export_dir var output_directory: String = "res://export/capture/"

## The filename of the captured image (without extension).
@export var filename: String = "capture_zone_image"

## Scenario name for metadata.
@export var scenario: String = ""

func _ready() -> void:
	# run only in editor build
	if recapture:
		_capture_in_editor()

## Captures an image of the content within a specific child collision node.
## Returns an Image object or null if failed.
func capture_content(child: Node2D = null) -> Image:
	var global_aabb: Rect2
	
	if child:
		var child_rect: Rect2
		if child is CollisionShape2D and child.shape:
			child_rect = child.shape.get_rect()
		else:
			push_warning("CaptureZone2D: Provided node is not a supported collision shape.")
			return null
		
		# Get the world axis-aligned bounding box of this child
		global_aabb = child.global_transform * child_rect
	else:
		push_warning("CaptureZone2D: No child node provided. Capturing entire zone.")
		return null

	if global_aabb.size.x <= 0 or global_aabb.size.y <= 0:
		push_warning("CaptureZone2D: Capture area is empty or invalid.")
		return null

	var viewport := get_viewport()
	if not viewport:
		return null
	
	var sub_viewport := SubViewport.new()
	add_child(sub_viewport)
	
	sub_viewport.size = global_aabb.size as Vector2i
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.world_2d = viewport.world_2d
	
	var camera := Camera2D.new()
	sub_viewport.add_child(camera)
	
	camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	camera.position = global_aabb.position
	camera.make_current()
	
	# Wait for the frame to be drawn (multiple frames for reliability in editor)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img = sub_viewport.get_texture().get_image()
	
	# Cleanup
	remove_child(sub_viewport)
	sub_viewport.queue_free()
	
	return img

## Internal function to trigger capture from the editor.
func _capture_in_editor() -> void:
	if not Engine.is_editor_hint():
		# This is intended for use in the editor, but can be called from code.
		pass

	var metadata: Dictionary = {}

	# Create output directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_recursive_absolute(output_directory)

	for child in get_children():
		if (child is CollisionShape2D and child.shape):
			var shape_filename := name + "_" + child.name
			var save_path := output_directory.path_join(shape_filename + ".png")

			var img = await capture_content(child)
			if img is Image:
				var err := img.save_png(save_path)
				if err == OK:
					print("CaptureZone2D: Image saved to ", save_path)

					var child_rect: Rect2 = child.shape.get_rect()
					var global_aabb: Rect2 = child.global_transform * child_rect
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
					push_error("CaptureZone2D: Failed to save image to ", save_path, " (Error: ", err, ")")
	
	if metadata.size() > 0:
		var meta_path = output_directory.path_join(name + "_metadata.json")
		var meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
		if meta_file:
			meta_file.store_string(JSON.stringify(metadata, "\t"))
			meta_file.close()
			print("CaptureZone2D: Metadata saved to ", meta_path)
		
		# Trigger a filesystem scan so the new images appear in the editor
		if Engine.is_editor_hint():
			var editor_interface = EditorInterface.get_resource_filesystem()
			if editor_interface:
				editor_interface.scan()
	else:
		push_warning("CaptureZone2D: No valid collision shapes found to capture or all captures failed.")
