class_name DoorType
extends RefCounted

## Tipos semánticos y arquitectónicos de vanos y puertas en la mazmorra (Fase Reforced).

enum DoorType {
	CLOSED_DOOR = 0,   ## Puerta física de madera interactiva y destructible
	LOCKED_DOOR = 1,   ## Puerta bloqueada que requiere llave o ítem de misión
	OPEN_PASSAGE = 2   ## Vano o arco de piedra abierto (sin hoja de puerta de madera)
}
