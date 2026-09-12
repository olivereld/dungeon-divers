# RiverNetworkMeshBuilder.gd
# Entry point for building river network meshes. This file provides an isolated
# contract-only implementation for the new renderer entry point. NO geometry
# algorithms are introduced here — only documentation and an empty return
# structure (WaterSurfaceData) so integration points can be frozen.

extends Node
class_name RiverNetworkMeshBuilder

# ---------------------------------------------------------------------------
# Contrato de entrada (Input contract)
# ---------------------------------------------------------------------------
# Este builder espera recibir, como entrada, tres objetos que vienen del
# generador de mundo:
#   - river_network: instancia de RiverNetwork que contiene la topología de
#     los ríos (listas de River, puntos, widths, depths, etc.).
#   - world_result: resultado de la etapa de generación del mundo (heightmap,
#     tiles, carving, hydrology result, etc.). Debe contener la información
#     necesaria para posicionar la geometría en 3D.
#   - world_profile: parámetros globales del mundo (escalas, offsets, unidades,
#     metadatos que afecten a la malla/UVs/materiales).
#
# Nota: NO se deben mutar los objetos de entrada aquí. Este builder actúa como
# un consumidor puro del estado generado.

# ---------------------------------------------------------------------------
# Contrato de salida (Output contract)
# ---------------------------------------------------------------------------
# WaterSurfaceData (representado como Dictionary) — estructura esperada por el
# renderer nuevo. Campos sugeridos (pueden ajustarse según integración):
#   - vertices: PoolVector3Array (o Array de Vector3) — posiciones 3D.
#   - indices: PoolIntArray (o Array de int) — índices para forming faces.
#   - uvs: PoolVector2Array — coordenadas UV por vértice.
#   - normals: PoolVector3Array — normales por vértice (opcional inicialmente).
#   - material: Resource | null — material o referencia a material.
#   - metadata: Dictionary — información auxiliar (e.g., source_river_id,
#     LOD hints, bounds, bounds_aabb, etc.).
#
# Por ahora este builder devuelve una estructura vacía con las claves esperadas
# para que el resto del sistema pueda depender del contrato sin que exista la
# nueva lógica geométrica todavía.

# ---------------------------------------------------------------------------
# API pública
# ---------------------------------------------------------------------------
# build_from_river_network(river_network, world_result, world_profile)
#   Ejecuta el builder y devuelve WaterSurfaceData (Dictionary).
#   - No implementa geometría todavía: devuelve la estructura vacía.
#
func build_from_river_network(river_network, world_result, world_profile) -> Dictionary:
	# Validaciones mínimas para detectar integraciones rotas lo antes posible.
	if river_network == null:
		push_error("RiverNetworkMeshBuilder: river_network is null")
		return _empty_water_surface_data()
	if world_result == null:
		push_error("RiverNetworkMeshBuilder: world_result is null")
		return _empty_water_surface_data()
	if world_profile == null:
		push_error("RiverNetworkMeshBuilder: world_profile is null")
		return _empty_water_surface_data()

	# NO generar ningún algoritmo de malla aquí. Simplemente devolver la forma
	# del contrato para que el nuevo renderer tenga un punto de integración.
	return _empty_water_surface_data()

func _empty_water_surface_data() -> Dictionary:
	return {
		"vertices": PoolVector3Array(),
		"indices": PoolIntArray(),
		"uvs": PoolVector2Array(),
		"normals": PoolVector3Array(),
		"material": null,
		"metadata": {}
	}

# ---------------------------------------------------------------------------
# Helpers / Documentación runtime
# ---------------------------------------------------------------------------
func get_input_contract_doc() -> Dictionary:
	return {
		"river_network": "RiverNetwork (topology, points, widths, depths)",
		"world_result": "WorldResult (heightmap, carving, hydrology data)",
		"world_profile": "WorldProfile (scale, units, material hints)"
	}

func get_output_contract_doc() -> Dictionary:
	return {
		"WaterSurfaceData": ["vertices", "indices", "uvs", "normals", "material", "metadata"]
	}
