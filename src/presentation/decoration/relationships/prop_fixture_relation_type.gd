class_name PropFixtureRelationType
extends RefCounted

## Tipos de afinidad o rol semántico entre un Prop y un Fixture arquitectónico.

enum Type {
	COMPANION = 0,   ## Acompañamiento estrecho / flanqueo directo
	SUPPORT = 1,     ## Soporte secundario o ambiental
	ACCENT = 2,      ## Acento sutil de detalle
	CEREMONIAL = 3   ## Disposición ritual o solemne
}
