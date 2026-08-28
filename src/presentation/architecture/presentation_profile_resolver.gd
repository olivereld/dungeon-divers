class_name PresentationProfileResolver
extends RefCounted

## Resolvedor canónico y puro de perfiles de presentación arquitectónica.
## Transforma perfiles de sala y estilos declarativos en ArchitecturalPresentationProfile.
## 100% puro: no depende de nodos de escena, mallas 3D ni nombres hardcodeados de mazmorras.

const _DungeonArchetypeScript = preload("res://src/dungeon_generator/core/semantic/archetype/dungeon_archetype.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")
const _ArchitecturalStyleScript = preload("res://src/presentation/architecture/architectural_style.gd")
const _ArchitecturalPresentationProfileScript = preload("res://src/presentation/architecture/architectural_presentation_profile.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")

func resolve_profile_for_archetype(
	archetype_id: Variant,
	purpose: Variant = &"generic",
	room_profile: RefCounted = null
) -> _ArchitecturalPresentationProfileScript:
	if room_profile is _ProfileRoomScript and room_profile.architecture != null:
		return resolve_from_room_profile(room_profile, archetype_id, purpose)

	return _resolve_generic(purpose)

func resolve(archetype: Variant, purpose: Variant, room_profile: RefCounted = null) -> _ArchitecturalPresentationProfileScript:
	return resolve_profile_for_archetype(archetype, purpose, room_profile)

func resolve_from_room_profile(
	p_room_profile: _ProfileRoomScript,
	fallback_archetype: Variant = &"generic",
	fallback_purpose: Variant = &"generic"
) -> _ArchitecturalPresentationProfileScript:
	if p_room_profile == null or p_room_profile.architecture == null:
		return _resolve_generic(fallback_purpose)

	var arch = p_room_profile.architecture
	var fallback_prof := _resolve_generic(fallback_purpose)

	var floor_st: StringName = _ArchitecturalStyleScript.floor_from_name(str(arch.floor), fallback_prof.floor_style)
	var wall_st: StringName = _ArchitecturalStyleScript.wall_from_name(str(arch.walls), fallback_prof.wall_style)
	var door_st: StringName = _ArchitecturalStyleScript.door_from_name(str(arch.door), fallback_prof.door_style)
	var stairs_st: StringName = _ArchitecturalStyleScript.stairs_from_name(str(arch.stairs), fallback_prof.stairs_style)

	var res_prof := _ArchitecturalPresentationProfileScript.new(
		floor_st,
		wall_st,
		door_st,
		stairs_st,
		fallback_prof.fixture_style,
		fallback_prof.decoration_palette
	)
	if arch.wall_variants != null:
		res_prof.wall_variants = arch.wall_variants
	if arch.floor_variants != null:
		res_prof.floor_variants = arch.floor_variants
	return res_prof

func _resolve_generic(purpose: Variant = &"generic") -> _ArchitecturalPresentationProfileScript:
	return _ArchitecturalPresentationProfileScript.new(
		&"generic_stone",
		&"generic_stone",
		&"stone_arch",
		&"stone",
		&"torch",
		&"generic"
	)
