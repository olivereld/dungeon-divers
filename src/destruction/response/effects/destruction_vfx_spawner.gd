class_name DestructionVFXSpawner
extends RefCounted

## Spawner agnóstico y desacoplado de efectos visuales (VFX).
## Su única responsabilidad es resolver el effect_id a través de DestructionVFXRegistry,
## instanciar la PackedScene correspondiente, posicionarla en el transform dado y añadirla al árbol.

const _VFXRegistryScript = preload("res://src/destruction/response/effects/destruction_vfx_registry.gd")

var _registry: _VFXRegistryScript = null

func _init(registry: _VFXRegistryScript = null) -> void:
	_registry = registry if registry != null else _VFXRegistryScript.new()

func get_registry() -> _VFXRegistryScript:
	return _registry

## Instancia el efecto visual correspondiente en el transform y parent especificados.
## Retorna la instancia de Node3D (VFXInstance) o null si el efecto no existe.
func spawn_effect(effect_id: String, xform: Transform3D, parent: Node3D = null) -> Node3D:
	if _registry == null or effect_id == "" or effect_id == "none":
		return null

	var scn: PackedScene = _registry.get_scene(effect_id)
	if scn == null:
		return null

	var vfx_node = scn.instantiate() as Node3D
	if vfx_node == null:
		return null

	if parent != null and is_instance_valid(parent):
		vfx_node.transform = xform
		parent.add_child(vfx_node)
		vfx_node.global_transform = xform
		if vfx_node.has_method("play"):
			vfx_node.play()
	else:
		vfx_node.transform = xform
		if vfx_node.has_method("play"):
			vfx_node.play()

	return vfx_node
