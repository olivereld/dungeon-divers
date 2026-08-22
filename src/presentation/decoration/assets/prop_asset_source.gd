class_name PropAssetSource
extends RefCounted

## Fuente de materialización de un prop.
## Define si el asset proviene de una PackedScene (.tscn) o de un generador procedural.

enum SourceType {
	PACKED_SCENE = 0, ## Escena empaquetada prediseñada (.tscn)
	PROCEDURAL = 1    ## Geometría procedural generada en tiempo de ejecución
}

static func source_to_name(source: int) -> String:
	match source:
		SourceType.PACKED_SCENE:
			return "PACKED_SCENE"
		SourceType.PROCEDURAL:
			return "PROCEDURAL"
		_:
			return "UNKNOWN"
