class_name PropAssetProvider
extends RefCounted

## Materializador resiliente de Room Props.
## Despacha definiciones de assets (PropAssetDefinition) hacia su origen (PackedScene o Geometría Procedural)
## con control explícito de fallos para evitar caídas catastróficas de generación.

const _PropAssetDefinitionScript = preload("res://src/presentation/decoration/assets/prop_asset_definition.gd")
const _PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")
const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropProceduralFactoryScript = preload("res://src/presentation/decoration/assets/prop_procedural_factory.gd")

var _registry := _PropAssetRegistryScript.new()
var _procedural_factory := _PropProceduralFactoryScript.new()

func get_registry() -> _PropAssetRegistryScript:
	return _registry

func set_registry(reg: _PropAssetRegistryScript) -> void:
	if reg != null:
		_registry = reg

func materialize_by_id(prop_id: StringName) -> Node3D:
	if not _registry.has_definition(prop_id):
		push_warning("[PropAssetProvider] ID de prop no registrado: %s. Saltando materialización." % str(prop_id))
		return null

	var def = _registry.get_definition(prop_id)
	return instantiate(def)

func instantiate(definition: _PropAssetDefinitionScript) -> Node3D:
	if definition == null:
		push_warning("[PropAssetProvider] PropAssetDefinition nulo.")
		return null

	var node: Node3D = null

	match definition.source_type:
		_PropAssetSourceScript.SourceType.PACKED_SCENE:
			if definition.scene == null:
				push_warning("[PropAssetProvider] PackedScene nula para prop_id: %s" % str(definition.id))
				return null
			node = definition.scene.instantiate() as Node3D

		_PropAssetSourceScript.SourceType.PROCEDURAL:
			if definition.procedural_builder_id == &"":
				push_warning("[PropAssetProvider] procedural_builder_id no especificado para prop_id: %s" % str(definition.id))
				return null
			node = _procedural_factory.build_procedural_prop(definition.procedural_builder_id, definition.procedural_params)

		_:
			push_warning("[PropAssetProvider] Tipo de origen desconocido (%d) para prop_id: %s" % [definition.source_type, str(definition.id)])
			return null

	return node
