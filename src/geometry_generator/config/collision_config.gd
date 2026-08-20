class_name CollisionConfig
extends Resource

## Configuración de políticas de colisión física para el generador de geometría.

enum CollisionMode {
	NONE,               ## No generar colisionadores
	PER_SEGMENT_BOX,    ## Caja física orientada individual por cada arista
	COMPOUND_BOX,       ## Conjunto optimizado de cajas fusionando tramos colineales continuos
	CONCAVE_TRIMESH     ## Malla cóncava exacta (TrimeshCollision)
}

@export var mode: CollisionMode = CollisionMode.COMPOUND_BOX
@export var collision_margin: float = 0.04
@export var extra_thickness: float = 0.05
@export var generate_navmesh_obstacles: bool = false
