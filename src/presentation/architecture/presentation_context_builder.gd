class_name PresentationContextBuilder
extends RefCounted

## Orquestador puro de contextos de presentación arquitectónica.
## Transforma un DungeonSemanticResult en una colección de PresentationRoomContext y
## determina el perfil dominante para guiar el layout visual global y corredores.

const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _PresentationRoomRoleScript = preload("res://src/presentation/architecture/presentation_room_role.gd")
const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomProfileResolverScript = preload("res://src/dungeon_generator/profiles/room_profile_resolver.gd")
const _ProfileLoaderScript = preload("res://src/dungeon_generator/profiles/profile_loader.gd")

var _resolver := _PresentationProfileResolverScript.new()
var _profile_loader := _ProfileLoaderScript.new()
var _room_resolvers: Dictionary = {}

func build_contexts(semantic_result: DungeonSemanticResult) -> Array:
	var contexts: Array = []
	if semantic_result == null or semantic_result.rooms.is_empty():
		return contexts

	var arch_id: StringName = semantic_result.get_archetype_id() if semantic_result != null else &"necropolis"
	var arch_name: String = str(arch_id)
	var room_resolver := _get_room_resolver(arch_name)

	for room in semantic_result.rooms:
		var r_id: int = room.id
		var purpose: StringName = semantic_result.get_room_purpose(r_id)
		var room_prof = room_resolver.resolve(purpose) if room_resolver != null else null
		var prof: _ArchitecturalPresentationProfileScript = _resolver.resolve_profile_for_archetype(arch_id, purpose, room_prof)

		var role_type := _PresentationRoomRoleScript.Role.EXPLORE
		if r_id == semantic_result.start_room_id:
			role_type = _PresentationRoomRoleScript.Role.START
		elif r_id == semantic_result.boss_room_id:
			role_type = _PresentationRoomRoleScript.Role.BOSS
		else:
			for obj in semantic_result.objectives:
				if obj.room_id == r_id:
					role_type = _PresentationRoomRoleScript.Role.TREASURE if obj.type == 0 else _PresentationRoomRoleScript.Role.COMBAT
					break

		var ctx := _PresentationRoomContextScript.new(r_id, room.rect, purpose, prof, role_type, room_prof)
		contexts.append(ctx)

	return contexts

func _get_room_resolver(arch_name: String) -> _RoomProfileResolverScript:
	if _room_resolvers.has(arch_name):
		return _room_resolvers[arch_name]

	var bundle = _profile_loader.load_full_archetype_bundle(arch_name)
	if bundle != null and bundle.archetype != null:
		var r := _RoomProfileResolverScript.new(bundle)
		_room_resolvers[arch_name] = r
		return r

	return null


func get_dominant_profile(contexts: Array, fallback_archetype: Variant = &"necropolis") -> _ArchitecturalPresentationProfileScript:
	if contexts.is_empty():
		return _resolver.resolve_profile_for_archetype(fallback_archetype, 0)
	for ctx in contexts:
		if ctx.role == _PresentationRoomRoleScript.Role.START:
			return ctx.profile
	return contexts[0].profile
