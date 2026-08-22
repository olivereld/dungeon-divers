class_name CandleClusterGeometryConfig
extends Resource

## Configuración procedural para el Cúmulo / Agrupación de Velas (Candle Cluster).

enum ClusterDensity {
	SMALL = 0,    ## Grupo pequeño (3 a 6 velas)
	MEDIUM = 1,   ## Cúmulo medio (8 a 14 velas)
	DENSE = 2,    ## Gran santuario / alfombra de velas (18 a 30 velas)
	CUSTOM = 3    ## Cantidad exacta configurable por candle_count
}

@export var scale_mult: float = 1.0
@export var density: ClusterDensity = ClusterDensity.MEDIUM
@export var candle_count: int = 12
@export var cluster_radius: float = 0.65
@export var min_height: float = 0.08
@export var max_height: float = 0.38
@export var min_radius: float = 0.022
@export var max_radius: float = 0.045
@export var generate_wax_pool: bool = true
@export var wax_color: Color = Color(0.93, 0.90, 0.82, 1.0)
@export var flame_color: Color = Color(1.0, 0.70, 0.20, 1.0)
@export var seed: int = 1337

func _init(
	p_density: ClusterDensity = ClusterDensity.MEDIUM,
	p_scale_mult: float = 1.0,
	p_seed: int = 1337
) -> void:
	density = p_density
	scale_mult = p_scale_mult
	seed = p_seed
	_apply_density_preset()

func _apply_density_preset() -> void:
	match density:
		ClusterDensity.SMALL:
			candle_count = 5
			cluster_radius = 0.35
		ClusterDensity.MEDIUM:
			candle_count = 12
			cluster_radius = 0.60
		ClusterDensity.DENSE:
			candle_count = 24
			cluster_radius = 0.85
		_:
			pass
