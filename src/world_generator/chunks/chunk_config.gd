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

## Radio de renderizado / streaming en chunks (por defecto 2 para mantener 12-16 chunks activos)
var render_distance: int = 2

## Activar streaming circular para mantener 12-16 chunks optimizados
var circular_streaming: bool = true

## Margen de histéresis de descarga para evitar que caiga el número de chunks mientras se avanza
var unload_margin: float = 0.65

func _init(p_chunk_size: int = 16, p_margin: int = 1, p_render_dist: int = 1) -> void:
	chunk_size = p_chunk_size
	generation_margin = p_margin
	render_distance = p_render_dist
