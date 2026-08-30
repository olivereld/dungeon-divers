class_name DungeonLabInspector
extends RefCounted

## Inspector diagnóstico que consume directamente la API pública de RoomTemplateResolver.

const _RoomTemplateResolverScript = preload("res://src/dungeon_generator/core/room_templates/resolver/room_template_resolver.gd")

func inspect_room(
	room: RoomData,
	bundle: ProfileBundle,
	p_seed: int = 0,
	entrances: Array[Vector2i] = []
) -> Dictionary:
	if room == null or bundle == null:
		return {}

	var room_profile = bundle.get_room(room.room_type)
	if room_profile == null and bundle.archetype != null:
		var g_map: Dictionary = bundle.archetype.gameplay_purpose_map
		var key: String = str(room.room_type).to_upper()
		if g_map.has(key) and not g_map[key].is_empty():
			var candidates_list: Array = g_map[key]
			var rng := RandomNumberGenerator.new()
			rng.seed = p_seed
			var mapped_purpose = candidates_list[rng.randi_range(0, candidates_list.size() - 1)]
			room_profile = bundle.get_room(mapped_purpose)

	var resolver := _RoomTemplateResolverScript.new(bundle.template_registry)
	var raw_diag := resolver.resolve_with_diagnostics(room, room_profile, entrances, p_seed)

	return {
		"room_id": room.id,
		"purpose": room.room_type,
		"profile_id": raw_diag.get("profile_id", &"none"),
		"resolved_template_id": raw_diag.get("resolved_template_id", &"procedural_fallback"),
		"is_fallback": raw_diag.get("is_fallback", true),
		"room_size": raw_diag.get("room_size", room.rect.size),
		"candidate_templates": raw_diag.get("candidate_templates", []),
		"compatible_templates": raw_diag.get("compatible_templates", []),
		"rejected_templates": raw_diag.get("rejected_templates", {})
	}
