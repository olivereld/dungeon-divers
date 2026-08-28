class_name DestructionService
extends RefCounted

## Servicio coordinador en tiempo de ejecución para el subsistema de destrucción.
## Mantiene el mapa activo de nodos destructibles y despacha eventos globales.

const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")
const _DestructionHitScript = preload("res://src/destruction/core/destruction_hit.gd")
const _DestructionEventScript = preload("res://src/destruction/core/destruction_event.gd")

signal global_destruction_event(event: _DestructionEventScript)

var _instances: Dictionary = {} # Node3D -> DestructionComponent
var _response_service: RefCounted = null

func set_response_service(resp_service: RefCounted) -> void:
	_response_service = resp_service

func get_response_service() -> RefCounted:
	return _response_service

func register_instance(node: Node3D, comp: _DestructionCompScript) -> void:
	if node != null and comp != null:
		_instances[node] = comp
		if not comp.destroyed.is_connected(_on_component_destroyed):
			comp.destroyed.connect(_on_component_destroyed)
		if not node.tree_exiting.is_connected(_on_node_exiting.bind(node)):
			node.tree_exiting.connect(_on_node_exiting.bind(node))

func unregister_instance(node: Node3D) -> void:
	if _instances.has(node):
		_instances.erase(node)

func get_component(node: Node3D) -> _DestructionCompScript:
	return _instances.get(node, null)

func apply_hit_to_node(node: Node3D, hit: _DestructionHitScript) -> bool:
	if node == null or hit == null:
		return false
	var comp = get_component(node)
	if comp != null:
		return comp.apply_hit(hit)
	# Check child component directly if not in registry map
	for c in node.get_children():
		if c is _DestructionCompScript:
			return (c as _DestructionCompScript).apply_hit(hit)
	return false

func get_active_count() -> int:
	return _instances.size()

func clear() -> void:
	_instances.clear()

func _on_component_destroyed(event: _DestructionEventScript) -> void:
	if _response_service != null and _response_service.has_method("handle_destruction_event"):
		_response_service.handle_destruction_event(event)
	global_destruction_event.emit(event)

func _on_node_exiting(node: Node3D) -> void:
	unregister_instance(node)
