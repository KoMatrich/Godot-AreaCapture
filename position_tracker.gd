extends Node

## PositionTracker autoload singleton.
## Manages a registry of trackable objects and handles position reports.

## Emitted when a trackable object reports its position.
signal position_reported(tag: String, node: Node, position: Variant)

# Dictionary of tag_name -> Array of Node
var _tracked_objects: Dictionary[String, Array] = {}

## Reports the position of a trackable object.
func report_position(tag: String, node: Node) -> void:
	var pos: Variant
	if node is Node2D:
		pos = node.global_position
	elif node is Node3D:
		pos = node.global_position
	else:
		push_warning("PositionTracker: Attempted to report position of unsupported node type.")
		return
	
	position_reported.emit(tag, node, pos)
	# For now, print the report to the console for verification.
	print("[%s] %s: %s" % [tag, node.name, pos])
	
	
## Registers a node with a specific tag.
func register_object(tag: String, node: Node) -> void:
	if tag == "":
		push_warning("PositionTracker: Attempted to register object with empty tag.")
		return
	if not _tracked_objects.has(tag):
		_tracked_objects[tag] = []
	if node not in _tracked_objects[tag]:
		_tracked_objects[tag].append(node)

## Unregisters a node with a specific tag.
func unregister_object(tag: String, node: Node) -> void:
	if _tracked_objects.has(tag):
		_tracked_objects[tag].erase(node)
		if _tracked_objects[tag].is_empty():
			_tracked_objects.erase(tag)

## Returns the first node associated with the given tag, or null if not found.
func get_tracked_object(tag: String) -> Node:
	var list = _tracked_objects.get(tag)
	if list and not list.is_empty():
		return list[0]
	return null

## Returns an array of all nodes associated with the given tag.
func get_tracked_objects(tag: String) -> Array:
	return _tracked_objects.get(tag, [])

## Returns the global position of the first node associated with the given tag.
## Returns Vector2.ZERO if it's 2D, Vector3.ZERO if it's 3D, or null if not found.
func get_position(tag: String) -> Variant:
	var obj = get_tracked_object(tag)
	if obj:
		if obj is Node2D or obj is Node3D:
			return obj.global_position
	return null

## Returns true if a tag is currently registered.
func has_tag(tag: String) -> bool:
	return _tracked_objects.has(tag)
