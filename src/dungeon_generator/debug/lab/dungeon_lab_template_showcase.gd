class_name DungeonLabTemplateShowcase
extends RefCounted

## Extrae y empaqueta representaciones visuales aisladas de todas las plantillas de un perfil.

const _RegistryScript = preload("res://src/dungeon_generator/core/room_templates/loader/room_template_registry.gd")
const _RoomTemplateScript = preload("res://src/dungeon_generator/core/room_templates/data/room_template.gd")

func showcase_profile(profile_id: StringName, registry: _RegistryScript) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if registry == null:
		return result

	var all_templates = registry.get_all_templates()
	for tpl in all_templates:
		if tpl.is_purpose_allowed(profile_id) or tpl.tags.has(profile_id) or str(tpl.id).begins_with(str(profile_id)):
			var cells: Array = []
			var doors: Array = []
			var w: int = 10
			var h: int = 10

			if tpl.custom_layout != null and not tpl.custom_layout.is_empty():
				cells = tpl.custom_layout.cells
				doors = tpl.custom_layout.internal_doors
				w = tpl.custom_layout.width
				h = tpl.custom_layout.height
			elif tpl.geometry != null:
				w = tpl.geometry.min_width
				h = tpl.geometry.min_depth
				for cy in range(h):
					for cx in range(w):
						cells.append(Vector2i(cx, cy))

			result.append({
				"id": tpl.id,
				"display_name": tpl.display_name,
				"template": tpl,
				"cells": cells,
				"internal_doors": doors,
				"width": w,
				"height": h,
				"tags": tpl.tags
			})

	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a["id"]) < str(b["id"])
	)
	return result
