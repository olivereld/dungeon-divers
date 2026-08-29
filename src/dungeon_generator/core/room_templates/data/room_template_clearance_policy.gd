class_name RoomTemplateClearancePolicy
extends RefCounted

## Política de zonas de despeje y seguridad (clearances) para RoomTemplates.
## Especifica distancias mínimas en celdas que deben mantenerse libres de obstáculos
## alrededor de vanos de acceso, puntos focales y circulación general.

var entrance: int = 1
var focal: int = 1
var circulation: int = 1
var walls: int = 0

func _init(
	p_entrance: int = 1,
	p_focal: int = 1,
	p_circulation: int = 1,
	p_walls: int = 0
) -> void:
	entrance = p_entrance
	focal = p_focal
	circulation = p_circulation
	walls = p_walls
