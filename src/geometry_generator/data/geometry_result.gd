class_name GeometryResult
extends RefCounted

## Contenedor de salida del generador de geometría 3D.
## Contiene los clusters de mallas generadas, diagnósticos de calidad y estadísticas.

var success: bool = true
var generated_meshes: Array[GeneratedMesh] = []
var diagnostics: Array[Dictionary] = []
var total_vertices: int = 0
var total_triangles: int = 0

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
	if generated_meshes.is_empty():
		return ArrayMesh.new()
	if generated_meshes.size() == 1:
		return generated_meshes[0].mesh if generated_meshes[0].mesh != null else ArrayMesh.new()

	var st := SurfaceTool.new()
	var unified := ArrayMesh.new()
	var slot_surfaces: Dictionary = {} # int -> Array of surface data / SurfaceTools

	for g_mesh in generated_meshes:
		if g_mesh.mesh == null:
			continue
		for surf_idx in range(g_mesh.mesh.get_surface_count()):
			if not slot_surfaces.has(surf_idx):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				var mat = g_mesh.mesh.surface_get_material(surf_idx)
				if mat != null:
					tool.set_material(mat)
				slot_surfaces[surf_idx] = tool
			slot_surfaces[surf_idx].append_from(g_mesh.mesh, surf_idx, Transform3D.IDENTITY)

	for surf_idx in slot_surfaces.keys():
		var tool: SurfaceTool = slot_surfaces[surf_idx]
		tool.index()
		tool.generate_tangents()
		unified = tool.commit(unified)

	return unified
