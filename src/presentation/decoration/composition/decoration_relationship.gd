class_name DecorationRelationship
extends RefCounted

## Relaciones espaciales declarativas entre elementos de decoración o con la geometría.

enum Relation {
	NEAR = 0,            ## A distancia cercana (1-2 celdas)
	ADJACENT = 1,        ## Inmediatamente adyacente (distancia Manhattan = 1)
	SYMMETRIC = 2,       ## Espejado con respecto a un eje o centro
	OPPOSITE = 3,        ## En el muro o lado opuesto de la sala
	CENTERED_ON = 4,     ## Centrado en el objeto o sala
	ALIGNED_WITH = 5,    ## Alineado longitudinalmente
	SUPPORTED_BY = 6,    ## Colocado sobre la superficie de otro elemento
	FACE_TOWARD = 7,     ## Orientado visualmente hacia otro elemento o centro
	KEEP_AWAY_FROM = 8   ## Prohibición de proximidad / exclusión mutua
}

static func relation_to_name(p_rel: int) -> String:
	match p_rel:
		Relation.NEAR:
			return "NEAR"
		Relation.ADJACENT:
			return "ADJACENT"
		Relation.SYMMETRIC:
			return "SYMMETRIC"
		Relation.OPPOSITE:
			return "OPPOSITE"
		Relation.CENTERED_ON:
			return "CENTERED_ON"
		Relation.ALIGNED_WITH:
			return "ALIGNED_WITH"
		Relation.SUPPORTED_BY:
			return "SUPPORTED_BY"
		Relation.FACE_TOWARD:
			return "FACE_TOWARD"
		Relation.KEEP_AWAY_FROM:
			return "KEEP_AWAY_FROM"
		_:
			return "UNKNOWN"

static func name_to_relation(p_name: String) -> int:
	match p_name.to_upper():
		"NEAR":
			return Relation.NEAR
		"ADJACENT":
			return Relation.ADJACENT
		"SYMMETRIC":
			return Relation.SYMMETRIC
		"OPPOSITE":
			return Relation.OPPOSITE
		"CENTERED_ON":
			return Relation.CENTERED_ON
		"ALIGNED_WITH":
			return Relation.ALIGNED_WITH
		"SUPPORTED_BY":
			return Relation.SUPPORTED_BY
		"FACE_TOWARD":
			return Relation.FACE_TOWARD
		"KEEP_AWAY_FROM":
			return Relation.KEEP_AWAY_FROM
		_:
			return Relation.NEAR
