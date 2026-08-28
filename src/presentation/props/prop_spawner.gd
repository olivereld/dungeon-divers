class_name PropSpawner
extends RefCounted

## Materializador de Room Props a partir de PropDirective.
## Delega la creación de nodos 3D en PropAssetProvider, aplicando posición,
## rotación, escala y metadatos sin acoplarse a configuraciones o generadores concretos.

const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionBinderScript = preload("res://src/destruction/runtime/destruction_binder.gd")

var _asset_provider: _PropAssetProviderScript = null
var _destruction_binder: _DestructionBinderScript = null

func _init(provider: _PropAssetProviderScript = null, binder: _DestructionBinderScript = null) -> void:
	_asset_provider = provider if provider != null else _PropAssetProviderScript.new()
	_destruction_binder = binder if binder != null else _DestructionBinderScript.new()

func get_asset_provider() -> _PropAssetProviderScript:
	return _asset_provider

func set_asset_provider(provider: _PropAssetProviderScript) -> void:
	if provider != null:
		_asset_provider = provider

func get_destruction_binder() -> _DestructionBinderScript:
	return _destruction_binder

func set_destruction_binder(binder: _DestructionBinderScript) -> void:
	if binder != null:
		_destruction_binder = binder

func spawn_prop(directive: _PropDirectiveScript, parent: Node3D = null) -> Node3D:
	if directive == null or directive.style == null:
		return null

	var seed_val: int = int(directive.world_position.x * 73.0 + directive.world_position.z * 37.0 + directive.room_id * 101.0)
	var node: Node3D = _asset_provider.materialize_by_id(directive.prop_id, seed_val)
	if node == null:
		node = Node3D.new()

	node.name = "Prop_%s_Room%d" % [String(directive.prop_id), directive.room_id]
	node.position = directive.world_position
	node.rotation.y = deg_to_rad(directive.rotation_degrees_y)
	
	var base_scale: Vector3 = node.scale
	var style_scale: float = directive.style.scale if directive.style.scale > 0.0 else 1.0
	node.scale = base_scale * style_scale

	node.set_meta("prop_directive", directive)
	node.set_meta("room_id", directive.room_id)

	if _destruction_binder != null and directive.prop_id != &"":
		_destruction_binder.bind_prop(node, directive.prop_id)

	if parent != null:
		parent.add_child(node, true)

	return node
