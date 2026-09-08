# stat_modifier_type.gd
class_name StatModifierType
extends RefCounted

enum Type {
	ADD,       # Suma directa antes de aplicar multiplicadores
	MULTIPLY,  # Porcentaje: se acumula como (1 + suma de todos los MULTIPLY)
}
