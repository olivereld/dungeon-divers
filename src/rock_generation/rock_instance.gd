class_name RockInstance
extends RefCounted

const RockSizeProfile = preload("res://src/rock_generation/rock_size_profile.gd")

## Representa una instancia concreta de roca con su transform calculado,
## escala asimétrica, rotación determinista y datos de variación para el shader.

var position: Vector3 = Vector3.ZERO
var scale: Vector3 = Vector3.ONE
var rotation_euler: Vector3 = Vector3.ZERO
var transform: Transform3D = Transform3D.IDENTITY
var category: int = 1 # RockSizeProfile.Category.MEDIUM
var variant_index: int = 0
var variation_value: float = 0.5 ## Enviado a INSTANCE_CUSTOM.r (0.0 a 1.0)
var custom_data: Color = Color(0.5, 0.0, 0.0, 1.0)

## Crea y calcula deterministamente una instancia de roca
static func create(
	p_position: Vector3,
	profile: Variant,
	rock_seed: int,
	ground_normal: Vector3 = Vector3.UP,
	p_category: int = 1
) -> RockInstance:
	var inst = new()
	inst.position = p_position
	inst.category = p_category

	# 1. Selección de variante de malla
	var num_vars: int = max(1, int(profile.num_variants))
	inst.variant_index = abs(_hash_int(rock_seed, 101)) % num_vars

	# 2. Escala base uniforme
	var scale_t: float = _hash_float(rock_seed, 201)
	var min_s: float = float(profile.min_scale)
	var max_s: float = float(profile.max_scale)
	var uniform_scale: float = lerp(min_s, max_s, scale_t)

	# 3. Variación de volumen no uniforme por ejes
	var sx_range: Vector2 = profile.get("scale_x_range") if profile.get("scale_x_range") != null else Vector2(0.85, 1.15)
	var sy_range: Vector2 = profile.get("scale_y_range") if profile.get("scale_y_range") != null else Vector2(0.80, 1.20)
	var sz_range: Vector2 = profile.get("scale_z_range") if profile.get("scale_z_range") != null else Vector2(0.85, 1.15)

	var sx_mult: float = lerp(sx_range.x, sx_range.y, _hash_float(rock_seed, 202))
	var sy_mult: float = lerp(sy_range.x, sy_range.y, _hash_float(rock_seed, 203))
	var sz_mult: float = lerp(sz_range.x, sz_range.y, _hash_float(rock_seed, 204))

	var h_ratio: float = float(profile.height_ratio)
	inst.scale = Vector3(
		uniform_scale * sx_mult,
		uniform_scale * sy_mult * h_ratio,
		uniform_scale * sz_mult
	)

	# 4. Rotación Y determinista (0° a 360°)
	var rot_y: float = _hash_float(rock_seed, 301) * TAU

	# 5. Inclinación sutil X y Z
	var max_tilt_deg: float = float(profile.get("max_tilt_degrees")) if profile.get("max_tilt_degrees") != null else 8.0
	var slope_tilt_deg: float = float(profile.get("slope_tilt_factor")) if profile.get("slope_tilt_factor") != null else 4.0
	var tilt_max_rad: float = deg_to_rad(max_tilt_deg)
	var tilt_x: float = (_hash_float(rock_seed, 302) - 0.5) * 2.0 * tilt_max_rad
	var tilt_z: float = (_hash_float(rock_seed, 303) - 0.5) * 2.0 * tilt_max_rad

	# Si el terreno tiene una inclinación suave, orientar ligeramente hacia la normal
	if ground_normal.y < 0.99 and ground_normal.y > 0.4:
		var slope_dir: Vector3 = (ground_normal - Vector3.UP * ground_normal.y).normalized()
		tilt_x += slope_dir.z * deg_to_rad(slope_tilt_deg)
		tilt_z += -slope_dir.x * deg_to_rad(slope_tilt_deg)

	inst.rotation_euler = Vector3(tilt_x, rot_y, tilt_z)

	# 6. Variación para el material
	inst.variation_value = lerp(0.25, 0.75, _hash_float(rock_seed, 401))
	inst.custom_data = Color(inst.variation_value, 0.0, 0.0, 1.0)

	# 7. Construcción de Transform3D
	var basis: Basis = Basis.from_euler(inst.rotation_euler)
	basis = basis.scaled(inst.scale)

	# Penetración proyectada a lo largo de la normal del terreno
	var base_pen: float = float(profile.base_penetration)
	var penetration_offset: float = base_pen * uniform_scale * 0.4
	var penetration_dir: Vector3 = ground_normal if ground_normal.y > 0.3 else Vector3.UP
	var final_pos: Vector3 = p_position - penetration_dir * penetration_offset

	inst.transform = Transform3D(basis, final_pos)
	return inst

static func _hash_float(seed_val: int, salt: int) -> float:
	var h: int = (seed_val * 73856093) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(abs(h) % 100000) / 100000.0

static func _hash_int(seed_val: int, salt: int) -> int:
	var h: int = (seed_val * 73856093) ^ (salt * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return h
