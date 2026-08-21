class_name RoomPurpose
extends RefCounted

## Identificador canónico y tipos de propósitos arquitectónicos de habitaciones.

enum Type {
	# Genérico
	GENERIC = 0,
	ENTRANCE = 1,
	HALL = 2,
	CHAMBER = 3,
	STORAGE = 4,

	# Mausoleum / Crypt
	CRYPT = 10,
	TOMB = 11,
	CATACOMB = 12,
	SACRISTY = 13,
	ROYAL_TOMB = 14,

	# Fortress
	ARMORY = 20,
	BARRACKS = 21,
	THRONE_ROOM = 22,
	GUARD_ROOM = 23,
	PRISON_CELLS = 24,

	# Temple
	SHRINE = 30,
	SANCTUM = 31,
	ALTAR_ROOM = 32,
	LIBRARY = 33,
	MEDITATION_ROOM = 34,

	# Mine
	EXCAVATION = 40,
	MINE_STORAGE = 41,
	FORGE = 42,
	ORE_CHAMBER = 43,
	WORKSHOP = 44
}

static func to_name(p_type: Type) -> String:
	for key in Type.keys():
		if Type[key] == p_type:
			return key
	return "UNKNOWN"

static func from_name(p_name: String) -> Type:
	var key := p_name.to_upper()
	if Type.has(key):
		return Type[key]
	return Type.GENERIC
