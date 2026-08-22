class_name FixturePlacementMode
extends RefCounted

## Taxonomía de modos de anclaje físico para fixtures arquitectónicos.

enum Mode {
	WALL = 0,     ## Adosado a un plano de muro vertical (ej. Antorcha, Farol de pared)
	FLOOR = 1,    ## Apoyado en suelo transitable (ej. Brasero de pie, Cúmulo de velas)
	SURFACE = 2,  ## Apoyado en una superficie horizontal de soporte (ej. Candelabro sobre peana/mesa/altar)
	HANGING = 3   ## Suspendido de un punto superior / bóveda (ej. Farol colgante con anilla)
}

static func mode_to_name(mode: int) -> String:
	match mode:
		Mode.WALL: return "WALL"
		Mode.FLOOR: return "FLOOR"
		Mode.SURFACE: return "SURFACE"
		Mode.HANGING: return "HANGING"
		_: return "UNKNOWN"
