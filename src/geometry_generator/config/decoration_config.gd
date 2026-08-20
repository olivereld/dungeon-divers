class_name DecorationConfig
extends Resource

## Configuración para decoraciones superficiales procedimentales (Ladrillos en relieve, ruido y relieves orgánicos).

enum DecorationStyle {
	NONE,
	STYLIZED_CLUSTERS,
	FULL_MASONRY
}

@export var style: DecorationStyle = DecorationStyle.STYLIZED_CLUSTERS
@export var enabled: bool = true
@export_range(0.1, 1.0, 0.05) var brick_density: float = 0.55
@export_range(0.2, 3.0, 0.05) var noise_frequency: float = 0.85
@export_range(0.15, 1.0, 0.02) var brick_width: float = 0.42
@export_range(0.08, 0.5, 0.01) var brick_height: float = 0.18
@export_range(0.0, 0.5, 0.02) var brick_size_variance: float = 0.22
@export_range(0.01, 0.15, 0.005) var brick_protrusion: float = 0.038
@export_range(0.0, 0.5, 0.05) var brick_depth_variance: float = 0.30
@export_range(0.01, 0.06, 0.002) var pillowed_bevel: float = 0.028
@export_range(0.0, 0.15, 0.01) var brick_jitter_rot: float = 0.04
@export var seed: int = 1337
