extends Node2D
class_name Trackable2D

## A simple node that registers its global position to the PositionTracker singleton.
## Add this node as a child of any object you want to track.

@export var tag_name: String = "Player"
## Report rate in Hz (reports per second). 0 means every frame.
@export var report_rate: float = 0.0
## Minimum distance the object must move (in pixels) from its last reported position to trigger a new report.
@export var move_threshold: float = 0.0

var _last_reported_position: Vector2 = Vector2.INF
var _time_since_last_report: float = 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	_time_since_last_report += delta
	
	var should_report = false
	if report_rate <= 0:
		should_report = true
	elif _time_since_last_report >= 1.0 / report_rate:
		should_report = true
	
	if not should_report:
		return
	
	var current_pos = global_position
	if move_threshold > 0:
		if _last_reported_position != Vector2.INF:
			if current_pos.distance_to(_last_reported_position) < move_threshold:
				return
	
	# Report!
	_last_reported_position = current_pos
	_time_since_last_report = 0.0
	PositionTracker.report_position(tag_name, self)

func _enter_tree() -> void:
	if not Engine.is_editor_hint():
		# Use call_deferred to ensure singleton is ready if it's the very first frame
		_register.call_deferred()

func _exit_tree() -> void:
	if not Engine.is_editor_hint():
		_unregister()

func _register() -> void:
	if tag_name != "":
		PositionTracker.register_object(tag_name, self)

func _unregister() -> void:
	if tag_name != "" and is_inside_tree():
		PositionTracker.unregister_object(tag_name, self)
