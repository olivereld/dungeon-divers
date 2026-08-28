class_name DestructionBinder
extends RefCounted

## Vinculador desacoplado que inspecciona nodos recién instanciados y
## les adjunta un DestructionComponent si su ID de asset está registrado en DestructionRegistry.

const _DestructionRegistryScript = preload("res://src/destruction/runtime/destruction_registry.gd")
const _DestructionServiceScript = preload("res://src/destruction/runtime/destruction_service.gd")
const _DestructionCompScript = preload("res://src/destruction/runtime/destruction_component.gd")

var _registry: _DestructionRegistryScript = null
var _service: _DestructionServiceScript = null

func _init(reg: _DestructionRegistryScript = null, srv: _DestructionServiceScript = null) -> void:
	_registry = reg if reg != null else _DestructionRegistryScript.new()
	_service = srv

func get_registry() -> _DestructionRegistryScript:
	return _registry

func set_service(srv: _DestructionServiceScript) -> void:
	_service = srv

func bind_prop(node: Node3D, prop_id: StringName) -> _DestructionCompScript:
	if node == null or not _registry.has_definition(prop_id):
		return null

	var def = _registry.get_definition(prop_id)
	if def == null or not def.enabled:
		return null

	# Evitar duplicar componentes si ya existe uno
	for child in node.get_children():
		if child is _DestructionCompScript:
			return child as _DestructionCompScript

	var comp := _DestructionCompScript.new(def)
	comp.name = "DestructionComponent"
	node.add_child(comp)

	if _service != null:
		_service.register_instance(node, comp)

	return comp
