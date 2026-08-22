class_name DecorationOrientationMode
extends RefCounted

## Modos de resolución de orientación angular (Yaw Y) para elementos decorativos.

enum Mode {
	FACE_ROOM = 0,    ## Orientado hacia el interior de la sala (espalda a la pared)
	FACE_WALL = 1,    ## Orientado mirando directamente hacia la pared (ej. cuadro, tapiz)
	FACE_CENTER = 2,  ## Orientado mirando hacia el centro geométrico o foco de la sala
	ALIGN_WALL = 3,   ## Alineado paralelamente al muro más cercano
	ALIGN_AXIS = 4,   ## Alineado al eje mayor/menor de la sala
	FREE = 5          ## Orientación libre o estocástica sin restricciones angulares
}

static func mode_to_name(p_mode: int) -> String:
	match p_mode:
		Mode.FACE_ROOM:
			return "FACE_ROOM"
		Mode.FACE_WALL:
			return "FACE_WALL"
		Mode.FACE_CENTER:
			return "FACE_CENTER"
		Mode.ALIGN_WALL:
			return "ALIGN_WALL"
		Mode.ALIGN_AXIS:
			return "ALIGN_AXIS"
		Mode.FREE:
			return "FREE"
		_:
			return "UNKNOWN"

static func name_to_mode(p_name: String) -> int:
	match p_name.to_upper():
		"FACE_ROOM":
			return Mode.FACE_ROOM
		"FACE_WALL":
			return Mode.FACE_WALL
		"FACE_CENTER":
			return Mode.FACE_CENTER
		"ALIGN_WALL":
			return Mode.ALIGN_WALL
		"ALIGN_AXIS":
			return Mode.ALIGN_AXIS
		"FREE":
			return Mode.FREE
		_:
			return Mode.FACE_ROOM
