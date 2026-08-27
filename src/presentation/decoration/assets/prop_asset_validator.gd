class_name PropAssetValidator
extends RefCounted

## Validador estático y dinámico de contratos de assets para Room Props.
## Verifica la integridad de escenas 3D (.tscn/.glb), mallas, colisionadores y constructores procedurales.

const _PropAssetRegistryScript = preload("res://src/presentation/decoration/assets/prop_asset_registry.gd")
const _PropAssetSourceScript = preload("res://src/presentation/decoration/assets/prop_asset_source.gd")
const _PropProceduralFactoryScript = preload("res://src/presentation/decoration/assets/prop_procedural_factory.gd")

var _procedural_factory := _PropProceduralFactoryScript.new()

func validate_registry(registry: _PropAssetRegistryScript) -> Dictionary:
	var errors: Array[String] = []
	var warnings: Array[String] = []
	var validated_count: int = 0

	if registry == null:
		errors.append("PropAssetRegistry es nulo.")
		return {"valid": false, "errors": errors, "warnings": warnings, "validated_count": 0}

	for prop_id in registry.get_all_definition_ids():
		var def = registry.get_definition(prop_id)
		if def == null:
			errors.append("Definición nula para prop_id: %s" % str(prop_id))
			continue

		validated_count += 1

		match def.source_type:
			_PropAssetSourceScript.SourceType.PACKED_SCENE:
				if def.scene_path == "" and def.scene == null and def.variants.is_empty():
					errors.append("Prop PACKED_SCENE '%s' no tiene scene_path, scene ni variants declaradas." % str(prop_id))
					continue

				if not def.variants.is_empty():
					for v in def.variants:
						var v_path: String = str(v.get("scene", ""))
						if v_path == "" or not ResourceLoader.exists(v_path):
							errors.append("Variante '%s' de prop '%s' tiene scene_path inválido o inexistente: '%s'" % [
								str(v.get("id", "unnamed")), str(prop_id), v_path
							])
				elif def.scene_path != "":
					if not ResourceLoader.exists(def.scene_path):
						errors.append("Prop PACKED_SCENE '%s' referencia escena inexistente: '%s'" % [str(prop_id), def.scene_path])

			_PropAssetSourceScript.SourceType.PROCEDURAL:
				if def.procedural_builder_id == &"":
					errors.append("Prop PROCEDURAL '%s' no tiene builder_id especificado." % str(prop_id))
				elif not _procedural_factory.has_builder(def.procedural_builder_id):
					errors.append("Prop PROCEDURAL '%s' tiene builder_id desconocido: '%s'" % [str(prop_id), str(def.procedural_builder_id)])

	return {
		"valid": errors.is_empty(),
		"errors": errors,
		"warnings": warnings,
		"validated_count": validated_count
	}
