# disposition.gd
# Valor continuo -100..100 en vez de un enum HOSTILE/NEUTRAL/FRIENDLY.
# Los thresholds son constantes de contrato para no repartir números mágicos
# por el código.
class_name Disposition
extends RefCounted

const MIN_VALUE := -100.0
const MAX_VALUE := 100.0
const HOSTILE_THRESHOLD := -50.0
const FRIENDLY_THRESHOLD := 50.0

var _value: float

func _init(p_value: float) -> void:
	_value = clamp(p_value, MIN_VALUE, MAX_VALUE)

var value: float:
	get: return _value

func is_hostile() -> bool:
	return _value <= HOSTILE_THRESHOLD

func is_friendly() -> bool:
	return _value >= FRIENDLY_THRESHOLD

func is_neutral() -> bool:
	return not is_hostile() and not is_friendly()

static func neutral() -> Disposition:
	return Disposition.new(0.0)
