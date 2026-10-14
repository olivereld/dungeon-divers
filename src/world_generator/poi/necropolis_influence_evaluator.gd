class_name NecropolisInfluenceEvaluator
extends RefCounted

const _ProfileScript = preload("res://src/world_generator/poi/necropolis_entrance_profile.gd")

## Evalúa la influencia espacial determinista de una entrada de Necrópolis sobre el terreno y vegetación.
## Aplica una perturbación fractal sobre la distancia para que el perímetro de corrupción sea orgánico y no un círculo plano.

enum {
	ZONE_CLEAR = 0,
	ZONE_FUNERAL = 1,
	ZONE_CORRUPTION = 2,
	ZONE_TRANSITION = 3,
	ZONE_WILD = 4,
}

static func evaluate_point(
	world_pos_2d: Vector2,
	poi_pos_2d: Vector2,
	seed_val: int,
	profile: RefCounted
) -> Dictionary:
	var raw_dist: float = (world_pos_2d - poi_pos_2d).length()

	# Zona inmediata de despeje absoluto (entrada sin obstrucción)
	if raw_dist <= profile.entrance_clear_radius:
		return {
			"influence": 1.0,
			"zone": ZONE_CLEAR,
			"is_cleared": true
		}

	# Perturbación angular/espacial determinista basada en funciones armónicas
	var angle: float = atan2(world_pos_2d.y - poi_pos_2d.y, world_pos_2d.x - poi_pos_2d.x)
	var noise_val: float = sin(angle * 3.0 + float(seed_val % 100)) * 2.2 + cos(angle * 5.0 + float(seed_val % 73)) * 1.5
	var effective_dist: float = raw_dist + noise_val

	if effective_dist <= profile.funeral_ground_radius:
		var t: float = 1.0 - (effective_dist / profile.funeral_ground_radius) * 0.25
		return {
			"influence": clampf(t, 0.75, 1.0),
			"zone": ZONE_FUNERAL,
			"is_cleared": false
		}
	elif effective_dist <= profile.corruption_radius:
		var span: float = profile.corruption_radius - profile.funeral_ground_radius
		var t: float = 1.0 - ((effective_dist - profile.funeral_ground_radius) / span)
		return {
			"influence": clampf(0.35 + t * 0.40, 0.35, 0.75),
			"zone": ZONE_CORRUPTION,
			"is_cleared": false
		}
	elif effective_dist <= profile.transition_radius:
		var span: float = profile.transition_radius - profile.corruption_radius
		var t: float = 1.0 - ((effective_dist - profile.corruption_radius) / span)
		return {
			"influence": clampf(t * 0.35, 0.0, 0.35),
			"zone": ZONE_TRANSITION,
			"is_cleared": false
		}
	else:
		return {
			"influence": 0.0,
			"zone": ZONE_WILD,
			"is_cleared": false
		}
