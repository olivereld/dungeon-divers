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

func _init(p_chunk_size: int = 16, p_margin: int = 1) -> void:
	chunk_size = p_chunk_size
	generation_margin = p_margin
