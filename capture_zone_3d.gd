extends Area3D
class_name CaptureZone3D

## Provides a bounding zone that captures a top-down PNG image of its 3D content.
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
@export var filename: String = ""

## Scenario name written into the metadata JSON.
@export var scenario: String = ""

func _ready() -> void:
	if recapture:
		_run_capture()

## Captures a top-down orthographic image of the content within a specific child collision node.
## Returns an Image object or null if failed.
func capture_content(child: Node3D = null) -> Image:
	var global_aabb: AABB

	if child:
		var collision_shape := child as CollisionShape3D
		if collision_shape and collision_shape.shape:
			var s := collision_shape.shape
			var size := Vector3.ONE
			var box := s as BoxShape3D
			var sphere := s as SphereShape3D
			var capsule := s as CapsuleShape3D
			var cylinder := s as CylinderShape3D
			if box:
				size = box.size
			elif sphere:
				size = Vector3(sphere.radius * 2.0, sphere.radius * 2.0, sphere.radius * 2.0)
			elif capsule:
				size = Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
			elif cylinder:
				size = Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)

			var local_aabb := AABB(-size / 2.0, size)
			global_aabb = collision_shape.global_transform * local_aabb
		else:
			push_warning("CaptureZone3D: Provided node is not a supported collision shape.")
			return null
	else:
		push_warning("CaptureZone3D: No child node provided.")
		return null

	if global_aabb.size.x <= 0 or global_aabb.size.z <= 0:
		push_warning("CaptureZone3D: Capture area is empty or invalid.")
		return null

	print("[CaptureZone3D] capture_content: AABB pos=%s size=%s" % [global_aabb.position, global_aabb.size])

	var viewport := get_viewport()
	if not viewport:
		push_warning("CaptureZone3D: No viewport available.")
		return null

	var sub_viewport := SubViewport.new()
	add_child(sub_viewport)

	# Image captured from top (X, Z plane). 100 px per world unit.
	sub_viewport.size = Vector2i(int(global_aabb.size.x * 100), int(global_aabb.size.z * 100))
	sub_viewport.transparent_bg = true
	# Defer rendering until the camera is positioned to avoid a blank frame.
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	sub_viewport.own_world_3d = false
	sub_viewport.world_3d = viewport.world_3d

	print("[CaptureZone3D] capture_content: SubViewport size=%s" % [sub_viewport.size])

	var camera := Camera3D.new()
	sub_viewport.add_child(camera)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# camera.size is the orthographic height in world units; width follows from SubViewport aspect ratio.
	camera.size = global_aabb.size.z

	var center := global_aabb.get_center()
	camera.global_position = center + Vector3(0, global_aabb.size.y / 2.0 + 1.0, 0)
	camera.look_at(center, Vector3.FORWARD)
	camera.make_current()

	print("[CaptureZone3D] capture_content: Camera3D position=%s size=%.4f look_at=%s" % [camera.global_position, camera.size, center])

	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	await get_tree().process_frame
	await RenderingServer.frame_post_draw

	var img = sub_viewport.get_texture().get_image()
	print("[CaptureZone3D] capture_content: Image size=%s" % [img.get_size() if img else Vector2i.ZERO])

	remove_child(sub_viewport)
	sub_viewport.queue_free()

	return img

## Captures all child CollisionShape3D zones and exports PNG + metadata JSON.
## Runs when the game starts with recapture=true; resets the flag when done.
func _run_capture() -> void:
	recapture = false
	print("[CaptureZone3D] _run_capture: started for '%s', output='%s'" % [name, output_directory])

	var metadata: Dictionary = {}

	if not DirAccess.dir_exists_absolute(output_directory):
		DirAccess.make_dir_recursive_absolute(output_directory)

	var rot_quat := Quaternion(global_transform.basis)

	for child in get_children():
		var collision_shape := child as CollisionShape3D
		if collision_shape and collision_shape.shape:
			var base: String = filename if filename != "" else name
			var shape_filename := base + "_" + collision_shape.name
			var save_path := output_directory.path_join(shape_filename + ".png")
			print("[CaptureZone3D] _run_capture: processing child '%s' -> '%s'" % [collision_shape.name, save_path])

			var img := await capture_content(collision_shape)
			if img:
				var err := img.save_png(save_path)
				if err == OK:
					print("[CaptureZone3D] _run_capture: saved '%s'" % [save_path])

					var s := collision_shape.shape
					var size := Vector3.ONE
					var box := s as BoxShape3D
					var sphere := s as SphereShape3D
					var capsule := s as CapsuleShape3D
					var cylinder := s as CylinderShape3D
					if box:
						size = box.size
					elif sphere:
						size = Vector3(sphere.radius * 2.0, sphere.radius * 2.0, sphere.radius * 2.0)
					elif capsule:
						size = Vector3(capsule.radius * 2.0, capsule.height, capsule.radius * 2.0)
					elif cylinder:
						size = Vector3(cylinder.radius * 2.0, cylinder.height, cylinder.radius * 2.0)

					var local_aabb := AABB(-size / 2.0, size)
					var global_aabb: AABB = child.global_transform * local_aabb
					var center := global_aabb.get_center()

					var key := name + "_" + child.name + "_Top"
					metadata[key] = {
						"filename": shape_filename + ".png",
						"cubemap_face": "Top",
						"global_position": {
							"x": center.x,
							"y": center.y,
							"z": center.z
						},
						"global_quaternion": {
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
					}
				else:
					push_error("CaptureZone3D: Failed to save '%s' (err=%d)" % [save_path, err])

	if metadata.size() > 0:
		var meta_path = output_directory.path_join(name + "_metadata.json")
		var meta_file = FileAccess.open(meta_path, FileAccess.WRITE)
		if meta_file:
			meta_file.store_string(JSON.stringify(metadata, "\t"))
			meta_file.close()
			print("[CaptureZone3D] _run_capture: metadata saved to '%s'" % [meta_path])
	else:
		push_warning("CaptureZone3D: No valid collision shapes found or all captures failed.")
