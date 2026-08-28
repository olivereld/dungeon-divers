class_name RoomProfileResolver
extends RefCounted

## Autoridad única para resolver cualquier RoomPurpose (int, enum, StringName, String)
## al ProfileRoom tipado correspondiente a partir de un ProfileBundle.
## 100% puro: no accede a archivos en disco ni depende de nodos de escena.

const _ProfileBundleScript = preload("res://src/dungeon_generator/profiles/profile_bundle.gd")
const _ProfileRoomScript = preload("res://src/dungeon_generator/profiles/profile_room.gd")
const _RoomPurposeScript = preload("res://src/dungeon_generator/core/semantic/archetype/room_purpose.gd")

var _bundle: _ProfileBundleScript = null
var _fallback_profile: _ProfileRoomScript = null

func _init(bundle: _ProfileBundleScript = null) -> void:
	_bundle = bundle
	_init_fallback()

func set_bundle(bundle: _ProfileBundleScript) -> void:
	_bundle = bundle
	_init_fallback()

func get_bundle() -> _ProfileBundleScript:
	return _bundle

## Resuelve un ProfileRoom a partir de un propósito de sala (int enum, StringName o String).
func resolve(purpose: Variant) -> _ProfileRoomScript:
	if _bundle == null:
		return _fallback_profile

	var key := _canonicalize_purpose_key(purpose)
	if _bundle.has_room(key):
		return _bundle.get_room(key)

	# Fallbacks contextuales comunes si el propósito específico no está en el bundle
	if key == &"generic" or key == &"chamber" or key == &"storage":
		if _bundle.has_room(&"chamber"):
			return _bundle.get_room(&"chamber")
		if _bundle.has_room(&"hall"):
			return _bundle.get_room(&"hall")
		if _bundle.has_room(&"crypt"):
			return _bundle.get_room(&"crypt")

	# Si hay al menos una sala cargada en el bundle, usar la primera como fallback
	if not _bundle.rooms.is_empty():
		var first_key = _bundle.rooms.keys()[0]
		return _bundle.rooms[first_key]

	return _fallback_profile

## Verifica si existe un perfil explícito cargado para el propósito indicado.
func has_profile_for(purpose: Variant) -> bool:
	if _bundle == null:
		return false
	var key := _canonicalize_purpose_key(purpose)
	return _bundle.has_room(key)

## Devuelve un diccionario de todos los perfiles de sala resueltos en el bundle.
func get_all_resolved_profiles() -> Dictionary:
	if _bundle == null:
		return {}
	return _bundle.rooms.duplicate()

func _canonicalize_purpose_key(purpose: Variant) -> StringName:
	return _RoomPurposeScript.resolve_id(purpose)

func _init_fallback() -> void:
	_fallback_profile = _ProfileRoomScript.new(&"generic_fallback", "Generic Fallback Room", 1)
