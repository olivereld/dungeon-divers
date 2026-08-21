# TorchGeometryBuilder
extends RefCounted

## Constructor geométrico procedural para luminarias y antorchas estilizadas (Fase M2 & Arquitectura Unificada).
## Construye un GeneratedAsset con dos slots:
## 1. "bracket": Soporte de hierro forjado inclinado.
## 2. "flame": Llama 3D emisiva estilizada.

const _GeneratedMeshScript = preload("res://src/geometry_generator/data/generated_mesh.gd")
const _GeneratedAssetScript = preload("res://src/geometry_generator/data/generated_asset.gd")
const _WallMaterialFactoryScript = preload("res://src/wall_mesh_generator/materials/wall_material_factory.gd")

func build_torch_fixture(bracket_length: float = 0.42, flame_scale: float = 1.0):
	var asset = _GeneratedAssetScript.new()
	asset.asset_id = &"torch_fixture_procedural"

	# 1. SOPORTE DE HIERRO (BRACKET)
	var g_bracket = _GeneratedMeshScript.new()
	g_bracket.component_id = 0

	var bracket_mesh := CylinderMesh.new()
	bracket_mesh.top_radius = 0.05
	bracket_mesh.bottom_radius = 0.025
	bracket_mesh.height = bracket_length
	g_bracket.mesh = bracket_mesh
	g_bracket.bounds = AABB(Vector3(-0.05, -bracket_length * 0.5, -0.05), Vector3(0.10, bracket_length, 0.10))
	g_bracket.material_slots[0] = _WallMaterialFactoryScript.create_iron_material()

	var bracket_xform := Transform3D.IDENTITY
	bracket_xform.basis = Basis(Vector3.RIGHT, PI * 0.18)
	bracket_xform.origin = Vector3(0.0, 0.0, 0.06)
	asset.add_mesh(&"bracket", g_bracket, bracket_xform)

	# 2. LLAMA EMISIVA (FLAME)
	var g_flame = _GeneratedMeshScript.new()
	g_flame.component_id = 1

	var flame_mesh := SphereMesh.new()
	flame_mesh.radius = 0.065 * flame_scale
	flame_mesh.height = 0.18 * flame_scale
	g_flame.mesh = flame_mesh
	g_flame.bounds = AABB(Vector3(-0.065, -0.09, -0.065) * flame_scale, Vector3(0.13, 0.18, 0.13) * flame_scale)

	var flame_mat := StandardMaterial3D.new()
	flame_mat.albedo_color = Color(1.0, 0.85, 0.45, 1.0)
	flame_mat.emission_enabled = true
	flame_mat.emission = Color(1.0, 0.60, 0.15)
	flame_mat.emission_energy_multiplier = 6.0
	g_flame.material_slots[0] = flame_mat

	var flame_xform := Transform3D.IDENTITY
	flame_xform.origin = Vector3(0.0, 0.22, 0.12)
	asset.add_mesh(&"flame", g_flame, flame_xform)

	asset.metadata["bracket_length"] = bracket_length
	asset.metadata["flame_scale"] = flame_scale

	return asset
