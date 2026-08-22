class_name CompositionRole
extends RefCounted

## Roles espaciales en la composición de una habitación (desacoplados del rol temático).

enum Role {
	PRIMARY = 0,    ## Elemento principal / eje dominante de la composición
	SECONDARY = 1,  ## Elemento de apoyo directo o contraparte simétrica
	COMPANION = 2,  ## Acompañamiento cercano (ej. vela junto a sarcófago)
	LIGHTING = 3,   ## Iluminación vinculada o perimetral
	DETAIL = 4      ## Detalles menores / ambientación
}

static func role_to_name(p_role: int) -> String:
	match p_role:
		Role.PRIMARY:
			return "PRIMARY"
		Role.SECONDARY:
			return "SECONDARY"
		Role.COMPANION:
			return "COMPANION"
		Role.LIGHTING:
			return "LIGHTING"
		Role.DETAIL:
			return "DETAIL"
		_:
			return "UNKNOWN"

static func name_to_role(p_name: String) -> int:
	match p_name.to_upper():
		"PRIMARY":
			return Role.PRIMARY
		"SECONDARY":
			return Role.SECONDARY
		"COMPANION":
			return Role.COMPANION
		"LIGHTING":
			return Role.LIGHTING
		"DETAIL":
			return Role.DETAIL
		_:
			return Role.DETAIL
