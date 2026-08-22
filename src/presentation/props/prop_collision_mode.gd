class_name PropCollisionMode
extends RefCounted

## Modos de colisión y ocupación para Room Props.
## Desacoplado de FixtureCollisionMode.

enum Mode {
	NONE = 0,        ## Sin colisión física ni bloqueo (ej. alfombras, runas grabadas)
	FOOTPRINT = 1,   ## Ocupa celdas lógicas pero permite traspaso físico o colisión suave
	BLOCKING = 2,    ## Bloquea físicamente paso y navegación (ej. sarcófago, altar, mesa)
	INTERACTIVE = 3  ## Bloqueante con capacidad de interacción por el jugador (ej. cofre de loot, palanca)
}

static func mode_to_name(mode: int) -> String:
	match mode:
		Mode.NONE:
			return "NONE"
		Mode.FOOTPRINT:
			return "FOOTPRINT"
		Mode.BLOCKING:
			return "BLOCKING"
		Mode.INTERACTIVE:
			return "INTERACTIVE"
		_:
			return "UNKNOWN"
