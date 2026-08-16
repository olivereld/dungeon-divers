class_name DungeonSeedFactory
extends RefCounted

## Fábrica de derivación de semillas deterministas por etapa e intento.
## Garantiza que para (base_seed, attempt, stage) la semilla resultante sea 100% determinista y reproducible.

const STAGE_OFFSETS: Dictionary = {
	&"mission": 0x1A2B3C4D,
	&"layout": 0x5E6F7A8B,
	&"topology": 0x9C0D1E2F,
	&"corridor": 0x3A4B5C6D,
	&"door": 0x7E8F9A0B,
	&"obstacle": 0xB1C2D3E4,
	&"variation": 0xF5A6B7C8,
	&"connectivity": 0x4D3C2B1A,
}

static func derive_seed(base_seed: int, attempt: int, stage: StringName) -> int:
	var stage_hash: int = STAGE_OFFSETS.get(stage, hash(stage))
	# Mezcla determinista de 64-bit bits
	var h: int = base_seed ^ (attempt * 0x9E3779B9) ^ stage_hash
	h = ((h >> 16) ^ h) * 0x45d9f3b
	h = ((h >> 16) ^ h) * 0x45d9f3b
	h = (h >> 16) ^ h
	# Evitar semilla 0
	return h if h != 0 else 1
