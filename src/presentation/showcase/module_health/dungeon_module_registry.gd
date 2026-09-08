class_name DungeonModuleRegistry
extends RefCounted

## Declarative registry of modules monitored by the Laboratory.
## Defines modules for health and pipeline inspection without controlling module activation.

static func get_modules() -> Array[Dictionary]:
	return [
		# --- Topology & Extraction ---
		{
			"id": "boundary_extractor",
			"name": "BoundaryExtractor",
			"path": "res://src/geometry_generator/extraction/boundary_extractor.gd",
			"category": "Topology"
		},
		{
			"id": "component_extractor",
			"name": "ComponentExtractor",
			"path": "res://src/geometry_generator/extraction/component_extractor.gd",
			"category": "Topology"
		},
		{
			"id": "wall_section_extractor",
			"name": "WallSectionExtractor",
			"path": "res://src/geometry_generator/extraction/wall_section_extractor.gd",
			"category": "Topology"
		},
		{
			"id": "solid_region_extractor",
			"name": "SolidRegionExtractor",
			"path": "res://src/geometry_generator/extraction/solid_region_extractor.gd",
			"category": "Topology"
		},

		# --- Geometry 3D ---
		{
			"id": "wall_geometry_builder",
			"name": "WallGeometryBuilder",
			"path": "res://src/geometry_generator/geometry/wall_geometry_builder.gd",
			"category": "Geometry"
		},
		{
			"id": "wall_path_geometry",
			"name": "WallPathGeometry",
			"path": "res://src/geometry_generator/geometry/wall_path_geometry.gd",
			"category": "Geometry"
		},
		{
			"id": "wall_profile_builder",
			"name": "WallProfileBuilder",
			"path": "res://src/geometry_generator/geometry/wall_profile_builder.gd",
			"category": "Geometry"
		},
		{
			"id": "solid_geometry_builder",
			"name": "SolidGeometryBuilder",
			"path": "res://src/geometry_generator/geometry/solid_geometry_builder.gd",
			"category": "Geometry"
		},
		{
			"id": "arch_geometry_builder",
			"name": "ArchGeometryBuilder",
			"path": "res://src/geometry_generator/geometry/arch_geometry_builder.gd",
			"category": "Geometry"
		},
		{
			"id": "door_geometry_builder",
			"name": "DoorGeometryBuilder",
			"path": "res://src/geometry_generator/geometry/door_geometry_builder.gd",
			"category": "Geometry"
		},
		{
			"id": "stair_geometry_builder",
			"name": "StairGeometryBuilder",
			"path": "res://src/geometry_generator/geometry/stair_geometry_builder.gd",
			"category": "Geometry"
		},

		# --- Variants & Collision ---
		{
			"id": "wall_variant_resolver",
			"name": "WallVariantResolver",
			"path": "res://src/geometry_generator/variants/wall_variant_resolver.gd",
			"category": "Variants"
		},
		{
			"id": "wall_collision_builder",
			"name": "WallCollisionBuilder",
			"path": "res://src/geometry_generator/collision/wall_collision_builder.gd",
			"category": "Collision"
		},

		# --- Decoration & Materials ---
		{
			"id": "brick_decorator",
			"name": "BrickDecorator",
			"path": "res://src/geometry_generator/decoration/brick_decorator.gd",
			"category": "Decoration"
		},
		{
			"id": "material_resolver",
			"name": "MaterialResolver",
			"path": "res://src/geometry_generator/decoration/material_resolver.gd",
			"category": "Materials"
		},

		# --- Gameplay & Testing ---
		{
			"id": "player_test",
			"name": "PlayerTest",
			"path": "res://src/character_test/player_test.gd",
			"category": "Gameplay"
		}
	]
