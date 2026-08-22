class_name PropFootprint
extends Resource

## Describe la huella espacial en celdas 2D que ocupa un Prop.
## Permite footprints simétricos (1x1) y multicelda (2x1, 3x1, 2x2), con rotación determinista.

@export var size: Vector2i = Vector2i.ONE ## Dimensiones en celdas (ancho X, profundidad Y)

func _init(p_size: Vector2i = Vector2i.ONE) -> void:
	size = p_size

## Devuelve el conjunto de celdas mundiales ocupadas a partir de una celda de origen y una rotación en múltiplos de 90°.
func get_occupied_cells(origin: Vector2i, rotation_deg: float = 0.0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var norm_rot: int = int(round(rotation_deg / 90.0)) % 4
	if norm_rot < 0:
		norm_rot += 4

	var w: int = size.x
	var h: int = size.y

	match norm_rot:
		0: # 0 grados: X hacia +X, Y hacia +Y
			for dx in range(w):
				for dy in range(h):
					cells.append(origin + Vector2i(dx, dy))
		1: # 90 grados: X hacia -Y, Y hacia +X
			for dx in range(w):
				for dy in range(h):
					cells.append(origin + Vector2i(dy, -dx))
		2: # 180 grados: X hacia -X, Y hacia -Y
			for dx in range(w):
				for dy in range(h):
					cells.append(origin + Vector2i(-dx, -dy))
		3: # 270 grados: X hacia +Y, Y hacia -X
			for dx in range(w):
				for dy in range(h):
					cells.append(origin + Vector2i(-dy, dx))

	return cells

func get_cell_count() -> int:
	return size.x * size.y
