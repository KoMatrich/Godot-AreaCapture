@tool
extends EditorPlugin

func _enter_tree() -> void:
	add_autoload_singleton("PositionTracker", "res://addons/Godot-AreaCapture/position_tracker.gd")
	add_custom_type("CaptureZone2D", "Area2D", preload("capture_zone_2d.gd"), preload("icon.svg"))
	add_custom_type("Trackable2D", "Node2D", preload("trackable_2d.gd"), preload("icon.svg"))
	add_custom_type("CaptureZone3D", "Node3D", preload("capture_zone_3d.gd"), preload("icon.svg"))
	add_custom_type("Trackable3D", "Node3D", preload("trackable_3d.gd"), preload("icon.svg"))

func _exit_tree() -> void:
	remove_autoload_singleton("PositionTracker")
	remove_custom_type("CaptureZone2D")
	remove_custom_type("Trackable2D")
	remove_custom_type("CaptureZone3D")
	remove_custom_type("Trackable3D")
