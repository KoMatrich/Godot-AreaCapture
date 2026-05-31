extends Area3D
class_name CaptureZone3D

## This script adds a special bounding box / script that can be applied to object.
## It is used to capture an image of their content from top.

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
## 3D scene image is captured using orthographic camera from top.
## Returns an Image object or null if failed.
func capture_content(child: Node3D = null) -> Image:
	var global_aabb: AABB
	
	if child:
		if child is CollisionShape3D and child.shape:
			# Get the world axis-aligned bounding box of this child
			# We approximate AABB using child's global position and some default size if we can't get it easily
			# For better accuracy, we can use the shape properties
			var s = child.shape
			var size := Vector3.ONE
			if s is BoxShape3D:
				size = s.size
			elif s is SphereShape3D:
				size = Vector3(s.radius * 2.0, s.radius * 2.0, s.radius * 2.0)
			elif s is CapsuleShape3D:
				size = Vector3(s.radius * 2.0, s.height, s.radius * 2.0)
			elif s is CylinderShape3D:
				size = Vector3(s.radius * 2.0, s.height, s.radius * 2.0)
			
			var local_aabb := AABB(-size / 2.0, size)
			global_aabb = child.global_transform * local_aabb
		else:
			push_warning("CaptureZone3D: Provided node is not a supported collision shape.")
			return null
	else:
		push_warning("CaptureZone3D: No child node provided.")
		return null

	if global_aabb.size.x <= 0 or global_aabb.size.z <= 0:
		push_warning("CaptureZone3D: Capture area is empty or invalid.")
		return null

	var viewport := get_viewport()
	if not viewport:
		return null
	
	var sub_viewport := SubViewport.new()
	add_child(sub_viewport)
	
	# Image captured from top (X, Z plane)
	sub_viewport.size = Vector2i(int(global_aabb.size.x * 100), int(global_aabb.size.z * 100)) # Scaling factor for 3D to Pixels
	sub_viewport.transparent_bg = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	sub_viewport.own_world_3d = false # Use same world
	sub_viewport.world_3d = viewport.world_3d
	
	var camera := Camera3D.new()
	sub_viewport.add_child(camera)
	
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = max(global_aabb.size.x, global_aabb.size.z)
	
	# Position camera above the center of AABB
	var center := global_aabb.get_center()
	camera.global_position = center + Vector3(0, global_aabb.size.y / 2.0 + 1.0, 0)
	camera.look_at(center, Vector3.FORWARD) # Use FORWARD to keep -Z as "up"
	
	camera.make_current()
	
	# Wait for the frame to be drawn
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	
	var img = sub_viewport.get_texture().get_image()
	
	# Cleanup
	remove_child(sub_viewport)
	sub_viewport.queue_free()
	
	return img

## Internal function to trigger capture from the editor.
func _capture_in_editor() -> void:
	var captures: Array = []
	
	# Create output directory if it doesn't exist
	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_recursive_absolute(output_directory)
	
	for child in get_children():
		if (child is CollisionShape3D and child.shape):
			var shape_filename := name + "_" + child.name
			var save_path := output_directory.path_join(shape_filename + ".png")
			
			var img = await capture_content(child)
			if img is Image:
				var err := img.save_png(save_path)
				if err == OK:
					print("CaptureZone3D: Image saved to ", save_path)
					
					captures.append({
						"filename": shape_filename + ".png",
						"type": "Top"
					})
				else:
					push_error("CaptureZone3D: Failed to save image to ", save_path, " (Error: ", err, ")")
	
	if captures.size() > 0:
		var global_aabb: AABB = AABB()
		var first_child = get_children()[0] as CollisionShape3D
		if first_child and first_child.shape:
			global_aabb = first_child.global_transform * first_child.shape.get_debug_mesh().get_aabb()
		
		var rot_quat = Quaternion(global_transform.basis)
		
		var metadata = {
			"name": name,
			"scenario": scenario,
			"transform": {
				"position": {
					"x": global_position.x,
					"y": global_position.y,
					"z": global_position.z
				},
				"rotation": {
					"x": rot_quat.x,
					"y": rot_quat.y,
					"z": rot_quat.z,
					"w": rot_quat.w
				},
				"size": {
					"x": global_aabb.size.x,
					"y": global_aabb.size.y,
					"z": global_aabb.size.z
				}
			},
			"captures": captures
		}
		
		var meta_path = output_directory.path_join(name + "_metadata.json")
		var meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
		if meta_file:
			meta_file.store_string(JSON.stringify(metadata, "\t"))
			meta_file.close()
			print("CaptureZone3D: Metadata saved to ", meta_path)
		
		# Trigger a filesystem scan so the new images appear in the editor
		if Engine.is_editor_hint():
			var editor_interface = EditorInterface.get_resource_filesystem()
			if editor_interface:
				editor_interface.scan()
	else:
		push_warning("CaptureZone3D: No valid collision shapes found to capture.")
