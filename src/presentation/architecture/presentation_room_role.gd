class_name PresentationRoomRole
extends RefCounted

## Roles funcionales de juego tipados para la presentación de habitaciones.

enum Role {
	START = 0,
	EXPLORE = 1,
	COMBAT = 2,
	TREASURE = 3,
	BOSS = 4
}

static func to_name(role: Role) -> String:
	match role:
		Role.START: return "START"
		Role.EXPLORE: return "EXPLORE"
		Role.COMBAT: return "COMBAT"
		Role.TREASURE: return "TREASURE"
		Role.BOSS: return "BOSS"
		_: return "UNKNOWN"
