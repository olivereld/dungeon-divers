class_name ChunkConfig
extends RefCounted

## Configuración de dimensiones, márgenes y políticas de generación para chunks.

## Tamaño en celdas por lado del chunk (16x16 celdas = 16m x 16m a cell_size 1.0m)
var chunk_size: int = 16

## Margen de halo en celdas para continuidad C1 de pendientes y normales en bordes
var generation_margin: int = 1

## Margen de halo en celdas para resolución determinista de proximidad de vegetación
var vegetation_margin: int = 4

## Rango de elevación de referencia (para normalización determinista idéntica al laboratorio)
var reference_min_height: float = 0.0
var reference_max_height: float = 0.0
var use_reference_height_range: bool = false

## Modo de coordenadas globales infinitas (ChunkWorld) vs dominio delimitado (Lab 64x64)
var is_unbounded: bool = false

## Radios de Streaming Desacoplados (VISIBLE < PRELOAD < CACHE)
var visible_radius: int = 2
var preload_radius: int = 5
var cache_radius: int = 8

## Distancia de proyección en chunks para predicción cinemática de movimiento
var prediction_distance_chunks: float = 2.0

## Presupuesto de tiempo de Main Thread para instanciación por frame (milisegundos)
var activation_budget_ms: float = 2.0
var max_chunk_activations_per_frame: int = 1

## Radio de renderizado / streaming en chunks (compatibilidad heredada)
var render_distance: int:
	get:
		return visible_radius
	set(val):
		visible_radius = val
		preload_radius = maxi(preload_radius, visible_radius + 2)
		cache_radius = maxi(cache_radius, preload_radius + 3)

## Activar streaming circular para mantener chunks optimizados
var circular_streaming: bool = true

## Margen de histéresis de descarga para evitar que caiga el número de chunks mientras se avanza
var unload_margin: float = 0.65

func _init(p_chunk_size: int = 16, p_margin: int = 1, p_render_dist: int = 2) -> void:
	chunk_size = p_chunk_size
	generation_margin = p_margin
	visible_radius = p_render_dist
	preload_radius = maxi(5, visible_radius + 2)
	cache_radius = maxi(8, preload_radius + 3)

