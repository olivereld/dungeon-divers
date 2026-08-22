class_name PropAssetProvider
extends RefCounted

## Proveedor unificado de assets y nodos 3D para Room Props.
## Desacopla la procedencia del asset (PackedScene prediseñada o malla procedural generada vía PropAssetRegistry).

const _PropDirectiveScript = preload("res://src/presentation/props/prop_directive.gd")
const _PropAssetRegistryScript = preload("res://src/presentation/props/prop_asset_registry.gd")

var _registry := _PropAssetRegistryScript.new()

func get_registry() -> _PropAssetRegistryScript:
	return _registry

func create_prop_node(directive: _PropDirectiveScript) -> Node3D:
	if directive == null or directive.style == null:
		return null

	# 1. Escena personalizada empaquetada (PackedScene)
	if directive.style.custom_scene != null:
		return directive.style.custom_scene.instantiate() as Node3D

	# 2. Generador procedural registrado en PropAssetRegistry
	if directive.style.generator_id != &"":
		return _registry.create_node(directive.style.generator_id, directive.style.generator_params)

	return null
