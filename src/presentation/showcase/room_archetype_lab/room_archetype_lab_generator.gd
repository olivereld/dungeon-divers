class_name RoomArchetypeLabGenerator
extends RefCounted

## Generador aislado de previsualizaciones de salas para el Room Archetype Lab.
## Consume directamente los resolvedores y spawners del pipeline de producción existente
## sin duplicar lógica ni generar mazmorras completas.

const _RoomPreviewRequestScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_request.gd")
const _RoomPreviewResultScript = preload("res://src/presentation/showcase/room_archetype_lab/room_preview_result.gd")
const _PresentationRoomContextScript = preload("res://src/presentation/architecture/presentation_room_context.gd")
const _PresentationRoomGeometryScript = preload("res://src/presentation/geometry/presentation_room_geometry.gd")
const _PresentationGeometryPartitionScript = preload("res://src/presentation/geometry/presentation_geometry_partition.gd")
const _PresentationProfileResolverScript = preload("res://src/presentation/architecture/presentation_profile_resolver.gd")
const _DecorationPaletteResolverScript = preload("res://src/presentation/decoration/decoration_palette_resolver.gd")
const _DecorationCompositionResolverScript = preload("res://src/presentation/decoration/decoration_composition_resolver.gd")
const _FixtureSpawnerScript = preload("res://src/presentation/fixtures/fixture_spawner.gd")
const _PropSpawnerScript = preload("res://src/presentation/props/prop_spawner.gd")
const _CellGridScript = preload("res://src/dungeon_generator/core/data/cell_grid.gd")

var _profile_resolver := _PresentationProfileResolverScript.new()
var _palette_resolver := _DecorationPaletteResolverScript.new()
var _composition_resolver := _DecorationCompositionResolverScript.new()
var _fixture_spawner := _FixtureSpawnerScript.new()
var _prop_spawner := _PropSpawnerScript.new()

func generate_preview(req: _RoomPreviewRequestScript) -> _RoomPreviewResultScript:
	if req == null:
		return _RoomPreviewResultScript.create_error(req, "Petición nula.")

	if not req.is_valid():
		return _RoomPreviewResultScript.create_error(req, "Combinación inválida de arquetipo y propósito o dimensiones insuficientes.")

	# 1. Construir geometría particionada aislada de la sala
	var r_geom := _PresentationRoomGeometryScript.new()
	r_geom.room_id = 1
	r_geom.bounds = Rect2i(0, 0, req.room_size.x, req.room_size.y)

	var floor_cells: Array[Vector2i] = []
	var wall_cells: Array[Vector2i] = []

	for y in range(req.room_size.y):
		for x in range(req.room_size.x):
			var cell := Vector2i(x, y)
			if x == 0 or x == req.room_size.x - 1 or y == 0 or y == req.room_size.y - 1:
				wall_cells.append(cell)
			else:
				floor_cells.append(cell)

	r_geom.floor_cells = floor_cells
	r_geom.wall_cells = wall_cells

	# Puertas y Escaleras opcionales para pruebas de despeje
	if req.has_door:
		var door_cell := Vector2i(1, req.room_size.y / 2)
		r_geom.door_positions.append(door_cell)

	if req.has_stairs:
		var stairs_cell := Vector2i(req.room_size.x - 2, req.room_size.y / 2)
		r_geom.stairs_positions.append(stairs_cell)

	# 2. Resolver perfiles y paletas de producción
	var profile = _profile_resolver.resolve(req.archetype, req.purpose)
	r_geom.profile = profile

	var palette = _palette_resolver.resolve_palette(req.archetype, req.purpose)

	# 3. Construir PresentationRoomContext y PresentationGeometryPartition de producción
	var r_ctx := _PresentationRoomContextScript.new()
	r_ctx.room_id = 1
	r_ctx.purpose = req.purpose
	r_ctx.profile = profile

	var partition := _PresentationGeometryPartitionScript.new()
	partition.rooms_geometry[r_geom.room_id] = r_geom

	# 4. Resolver composición espacial con el resolvedor de producción
	var comp = _composition_resolver.resolve_room_composition(
		r_ctx, palette, r_geom, partition, req.seed, req.tile_size
	)

	# 5. Materializar escena jerárquica 3D
	var room_root := Node3D.new()
	room_root.name = "RoomPreview_Root"

	# A. Subárbol Estructural (Suelo y Paredes base)
	var structural_node := Node3D.new()
	structural_node.name = "Structural"
	room_root.add_child(structural_node)
	_build_structural_preview(structural_node, r_geom, req.tile_size)

	# B. Subárbol de Fixtures
	_fixture_spawner.spawn_fixtures(comp.fixture_directives, room_root, null, req.tile_size)

	# C. Subárbol de Props
	var props_node := Node3D.new()
	props_node.name = "Props"
	room_root.add_child(props_node)
	for p_dir in comp.prop_directives:
		_prop_spawner.spawn_prop(p_dir, props_node)

	# D. Subárbol de Debug Overlay (Ocupación y Reservas)
	var debug_node := Node3D.new()
	debug_node.name = "DebugOverlay"
	room_root.add_child(debug_node)
	_build_debug_overlay(debug_node, r_geom, comp, req.tile_size)

	# 6. Recopilar diagnóstico en tiempo real
	var diag: Dictionary = {
		"archetype": req.archetype,
		"purpose": req.purpose,
		"seed": req.seed,
		"width": req.room_size.x,
		"depth": req.room_size.y,
		"floor_cells": r_geom.floor_cells.size(),
		"fixtures_count": comp.get_total_fixture_count(),
		"props_count": comp.get_total_prop_count(),
		"focal_count": comp.get_focal_props().size(),
		"support_count": comp.get_support_props().size(),
		"ambient_count": comp.get_ambient_props().size(),
		"functional_count": comp.get_functional_props().size(),
		"occupied_cells_count": comp.get_occupied_cell_count(),
		"reserved_cells_count": comp.get_reserved_cell_count(),
		"rejected_placements": comp.rejected_placements
	}

	var result := _RoomPreviewResultScript.new(req, true, "")
	result.room_context = r_ctx
	result.room_geometry = r_geom
	result.composition = comp
	result.room_root = room_root
	result.diagnostics = diag

	return result

func _build_structural_preview(parent: Node3D, r_geom: _PresentationRoomGeometryScript, tile_size: float) -> void:
	# Suelo
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(r_geom.bounds.size.x * tile_size, r_geom.bounds.size.y * tile_size)
	var floor_inst := MeshInstance3D.new()
	floor_inst.name = "FloorBase"
	floor_inst.mesh = floor_mesh
	floor_inst.position = Vector3(
		(r_geom.bounds.position.x + r_geom.bounds.size.x * 0.5) * tile_size,
		0.0,
		(r_geom.bounds.position.y + r_geom.bounds.size.y * 0.5) * tile_size
	)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.18, 0.18, 0.22)
	floor_mat.roughness = 0.85
	floor_inst.material_override = floor_mat
	parent.add_child(floor_inst)

	# Muros perimetrales
	var wall_mat := StandardMaterial3D.new()
	wall_mat.albedo_color = Color(0.28, 0.28, 0.32)
	wall_mat.roughness = 0.9

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(tile_size * 0.95, 2.5, tile_size * 0.95)

	for w_pos in r_geom.wall_cells:
		var wall_inst := MeshInstance3D.new()
		wall_inst.name = "Wall_%d_%d" % [w_pos.x, w_pos.y]
		wall_inst.mesh = wall_mesh
		wall_inst.position = Vector3(
			(w_pos.x + 0.5) * tile_size,
			1.25,
			(w_pos.y + 0.5) * tile_size
		)
		wall_inst.material_override = wall_mat
		parent.add_child(wall_inst)

func _build_debug_overlay(parent: Node3D, r_geom: _PresentationRoomGeometryScript, comp, tile_size: float) -> void:
	var tile_mesh := PlaneMesh.new()
	tile_mesh.size = Vector2(tile_size * 0.88, tile_size * 0.88)

	var occupied_mat := StandardMaterial3D.new()
	occupied_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	occupied_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.45) # Rojo translúcido

	var reserved_mat := StandardMaterial3D.new()
	reserved_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	reserved_mat.albedo_color = Color(1.0, 0.85, 0.1, 0.35)  # Amarillo/Ámbar translúcido

	# 1. Overlays de Celdas Reservadas
	for r_cell in comp.reserved_cells:
		var mi := MeshInstance3D.new()
		mi.name = "Reserved_%d_%d" % [r_cell.x, r_cell.y]
		mi.mesh = tile_mesh
		mi.position = Vector3((r_cell.x + 0.5) * tile_size, 0.03, (r_cell.y + 0.5) * tile_size)
		mi.material_override = reserved_mat
		parent.add_child(mi)

	# 2. Overlays de Celdas Ocupadas
	for o_cell in comp.occupied_cells:
		var mi := MeshInstance3D.new()
		mi.name = "Occupied_%d_%d" % [o_cell.x, o_cell.y]
		mi.mesh = tile_mesh
		mi.position = Vector3((o_cell.x + 0.5) * tile_size, 0.05, (o_cell.y + 0.5) * tile_size)
		mi.material_override = occupied_mat
		parent.add_child(mi)
