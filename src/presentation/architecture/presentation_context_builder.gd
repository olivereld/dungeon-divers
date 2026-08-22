class_name PresentationContextBuilder
extends RefCounted

## Orquestador puro de contextos de presentación arquitectónica.
## Transforma un DungeonSemanticResult en una colección de PresentationRoomContext y
## determina el perfil dominante para guiar el layout visual global.

const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")

var _resolver := _PresentationProfileResolverScript.new()

func build_contexts(semantic_result: DungeonSemanticResult) -> Array:
	var contexts: Array = []
	if semantic_result == null or semantic_result.rooms.is_empty():
		return contexts

	var archetype: int = semantic_result.dungeon_archetype

	for room in semantic_result.rooms:
		var r_id: int = room.id
		var purpose: int = semantic_result.get_room_purpose(r_id)
		var prof: _ArchitecturalPresentationProfileScript = _resolver.resolve(archetype, purpose)

		var role: String = "EXPLORE"
		if r_id == semantic_result.start_room_id:
			role = "START"
		elif r_id == semantic_result.boss_room_id:
			role = "BOSS"
		else:
			for obj in semantic_result.objectives:
				if obj.room_id == r_id:
					role = "TREASURE" if obj.type == 0 else "COMBAT"
					break

		var ctx := _PresentationRoomContextScript.new(r_id, room.rect, purpose, prof, role)
		contexts.append(ctx)

	return contexts

func get_dominant_profile(contexts: Array) -> _ArchitecturalPresentationProfileScript:
	if contexts.is_empty():
		return _resolver.resolve(0, 0)
	for ctx in contexts:
		if ctx.gameplay_role == "START":
			return ctx.profile
	return contexts[0].profile
