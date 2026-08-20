class_name FloorSurfaceResult
extends RefCounted

## Contenedor de salida de datos puros y clusters generados por DungeonFloorGenerator.

var success: bool = true
var clusters: Array = []
var diagnostics: Array[Dictionary] = []
var total_tiles_generated: int = 0
var total_descriptors_count: int = 0
var total_regions_count: int = 0

func add_diagnostic(code: String, severity: String, message: String) -> void:
	diagnostics.append({
		"code": code,
		"severity": severity.to_upper(),
		"message": message
	})
	if severity.to_upper() == "FATAL" or severity.to_upper() == "ERROR":
		success = false

func has_errors() -> bool:
	for d in diagnostics:
		var sev: String = str(d.get("severity", "INFO")).to_upper()
		if sev == "ERROR" or sev == "FATAL":
			return true
	return false

func get_unified_mesh() -> ArrayMesh:
	if clusters.is_empty():
		return ArrayMesh.new()
	if clusters.size() == 1:
		return clusters[0].mesh if clusters[0].mesh != null else ArrayMesh.new()

	var unified := ArrayMesh.new()
	var slot_surfaces: Dictionary = {}

	for cluster in clusters:
		if cluster.mesh == null:
			continue
		for surf_idx in range(cluster.mesh.get_surface_count()):
			if not slot_surfaces.has(surf_idx):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				var mat = cluster.mesh.surface_get_material(surf_idx)
				if mat != null:
					tool.set_material(mat)
				slot_surfaces[surf_idx] = tool
			slot_surfaces[surf_idx].append_from(cluster.mesh, surf_idx, Transform3D.IDENTITY)

	for surf_idx in slot_surfaces.keys():
		var tool: SurfaceTool = slot_surfaces[surf_idx]
		tool.index()
		tool.generate_tangents()
		unified = tool.commit(unified)

	return unified
