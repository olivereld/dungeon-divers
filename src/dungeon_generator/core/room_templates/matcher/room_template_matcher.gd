class_name RoomTemplateMatcher
extends RefCounted

## Emparejador inteligente de RoomTemplates según propósito semántico y criterios espaciales.

const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")
const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")

var _registry: _RegistryScript = null

func _init(p_registry: _RegistryScript) -> void:
	_registry = p_registry

func match_template_for_purpose(purpose_id: StringName, criteria: Dictionary = {}) -> _RoomTemplateScript:
	if _registry == null:
		return null

	var candidates: Array[_RoomTemplateScript] = _registry.get_all_templates()
	if candidates.is_empty():
		return null

	var best_template: _RoomTemplateScript = null
	var best_score: int = -1

	for tpl in candidates:
		var score: int = 0

		# 1. Coincidencia con propósito preferido (+100)
		if tpl.preferred_purposes.has(purpose_id):
			score += 100
		# 2. Coincidencia con propósito permitido (+50)
		elif tpl.allowed_purposes.has(purpose_id):
			score += 50
		# 3. Plantilla genérica (+10)
		elif tpl.allowed_purposes.is_empty():
			score += 10
		else:
			# Si el template tiene propósitos específicos y no incluye este, descartar
			continue

		# 4. Criterios adicionales opcionales (tags, etc.)
		var required_tags: Array = criteria.get("tags", [])
		for tag in required_tags:
			if tpl.tags.has(StringName(tag)):
				score += 5

		if score > best_score:
			best_score = score
			best_template = tpl

	return best_template

func find_compatible_templates(purpose_id: StringName) -> Array[_RoomTemplateScript]:
	var result: Array[_RoomTemplateScript] = []
	if _registry == null:
		return result

	for tpl in _registry.get_all_templates():
		if tpl.is_purpose_allowed(purpose_id):
			result.append(tpl)

	return result
