class_name DecorationRole
extends RefCounted

## Roles jerárquicos de intención estética para elementos de decoración (Props y Fixtures).
## Guía las prioridades del motor de composición espacial en cada habitación.

enum Role {
	FOCAL = 0,      ## Elemento principal dominante de la habitación (ej. sarcófago central, altar mayor, mesa de banquete)
	SUPPORT = 1,    ## Elementos secundarios que complementan el foco (ej. bancos, librerías, lápidas, estantes)
	AMBIENT = 2,    ## Elementos de ambientación y atmósfera (ej. escombros, urnas rotas, montones de huesos, cajas)
	FUNCTIONAL = 3  ## Elementos interactivos o mecánicos (ej. cofres de botín, palancas, trampas)
}

static func role_to_name(role: int) -> String:
	match role:
		Role.FOCAL:
			return "FOCAL"
		Role.SUPPORT:
			return "SUPPORT"
		Role.AMBIENT:
			return "AMBIENT"
		Role.FUNCTIONAL:
			return "FUNCTIONAL"
		_:
			return "UNKNOWN"

static func name_to_role(p_name: String) -> int:
	match p_name.to_upper():
		"FOCAL":
			return Role.FOCAL
		"SUPPORT":
			return Role.SUPPORT
		"AMBIENT":
			return Role.AMBIENT
		"FUNCTIONAL":
			return Role.FUNCTIONAL
		_:
			return Role.SUPPORT
