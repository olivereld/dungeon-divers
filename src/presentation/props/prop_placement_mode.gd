class_name PropPlacementMode
extends RefCounted

## Modos de anclaje y colocación espacial para Room Props.
## Desacoplado de FixturePlacementMode.

enum Mode {
	FLOOR = 0,  ## Suelo general transitable dentro de la sala
	WALL = 1,   ## Apoyado contra una pared interior (ej. librería, banco pegado)
	CENTER = 2, ## Posición central focal de la habitación (ej. altar, sarcófago principal)
	CORNER = 3  ## Esquina protegida de la sala (ej. urna, pila de escombros, cofre)
}

static func mode_to_name(mode: int) -> String:
	match mode:
		Mode.FLOOR:
			return "FLOOR"
		Mode.WALL:
			return "WALL"
		Mode.CENTER:
			return "CENTER"
		Mode.CORNER:
			return "CORNER"
		_:
			return "UNKNOWN"

static func name_to_mode(p_name: String) -> int:
	match p_name.to_upper():
		"FLOOR":
			return Mode.FLOOR
		"WALL":
			return Mode.WALL
		"CENTER":
			return Mode.CENTER
		"CORNER":
			return Mode.CORNER
		_:
			return Mode.FLOOR
