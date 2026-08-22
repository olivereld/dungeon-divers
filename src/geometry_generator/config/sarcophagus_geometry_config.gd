class_name SarcophagusGeometryConfig
extends Resource

## Configuración procedural para Sarcófagos y Féretros (Sarcophagus).
## Soporta estilos de Piedra Gótica (Mausoleo/Cripta) y Madera Rústica,
## con estados Abierto (Open) y Cerrado (Closed).

enum Style {
	GOTHIC_STONE = 0, ## Sarcófago de piedra tallada con relieves góticos y losa pesada
	RUSTIC_WOOD = 1   ## Féretro de madera con tablones y herrajes de refuerzo
}

enum State {
	CLOSED = 0,       ## Tapa cerrada y alineada sobre la base
	OPEN = 1,         ## Tapa desplazada e inclinada revelando el interior hueco
	BROKEN = 2        ## Tapa rota/desplazada a un lado
}

@export var scale_mult: float = 1.0
@export var style: Style = Style.GOTHIC_STONE
@export var is_open: bool = false
@export var is_broken: bool = false

# Dimensiones base (metros)
@export var length: float = 1.35                           ## Longitud longitudinal (Eje X)
@export var width: float = 0.65                            ## Anchura transversal (Eje Z)
@export var base_height: float = 0.44                      ## Altura del cajón/base
@export var lid_thickness: float = 0.12                    ## Grosor de la losa superior
@export var wall_thickness: float = 0.05                   ## Grosor de las paredes de la tina
@export var rim_overhang: float = 0.04                     ## Vuelo de molduras superior/inferior
@export var plinth_height: float = 0.06                    ## Altura del zócalo base

# Parámetros del estado abierto
@export var open_slide_x: float = 0.22                     ## Desplazamiento longitudinal de la tapa abierta
@export var open_slide_z: float = 0.14                     ## Desplazamiento transversal de la tapa abierta
@export var open_tilt_deg: float = 6.5                     ## Inclinación de la tapa apoyada sobre el borde
@export var open_rot_y_deg: float = 8.0                    ## Giro angular de la tapa en estado abierto

# Colores y Materiales
@export var stone_body_color: Color = Color(0.52, 0.53, 0.55, 1.0)      ## Piedra base de sarcófago
@export var stone_trim_color: Color = Color(0.66, 0.67, 0.70, 1.0)      ## Relieves, pilastras, runas y molduras
@export var wood_body_color: Color = Color(0.48, 0.32, 0.16, 1.0)       ## Tablones de féretro de madera
@export var wood_trim_color: Color = Color(0.62, 0.42, 0.22, 1.0)       ## Listones y refuerzos de madera
@export var iron_trim_color: Color = Color(0.28, 0.30, 0.34, 1.0)       ## Herrajes, bisagras y cantoneras
@export var interior_cloth_color: Color = Color(0.22, 0.14, 0.16, 1.0)  ## Revestimiento interior / tela o fondo oscuro
@export var seed: int = 1337

func _init(
	p_style: Style = Style.GOTHIC_STONE,
	p_is_open: bool = false,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	style = p_style
	is_open = p_is_open
	scale_mult = p_scale_mult
	seed = p_seed
