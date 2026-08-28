class_name DestructionReplacementConsumer
extends RefCounted

## Consumidor desacoplado que maneja la materialización de assets de reemplazo
## (ej. urna intacta -> urna rota / escombros) delegando en PropAssetProvider.

const _PropAssetProviderScript = preload("res://src/presentation/decoration/assets/prop_asset_provider.gd")
const _DestructionResponseContextScript = preload("res://src/destruction/response/destruction_response_context.gd")

var _provider: _PropAssetProviderScript = null

func _init(provider: _PropAssetProviderScript = null) -> void:
	_provider = provider if provider != null else _PropAssetProviderScript.new()

## Ejecuta el reemplazo si la definición del evento contiene un `replacement_asset`.
## Retorna el Node3D instanciado o null si no aplica.
func handle_replacement(ctx: _DestructionResponseContextScript, staging_parent: Node3D = null) -> Node3D:
	if ctx == null or ctx.event == null or ctx.event.definition == null:
		return null

	var rep_id = ctx.event.definition.replacement_asset
	if rep_id == &"" or rep_id == "none":
		return null

	if _provider == null:
		return null

	var rep_node = _provider.materialize_by_id(rep_id, ctx.seed_value)
	if rep_node == null:
		return null

	rep_node.transform = ctx.global_transform
	rep_node.set_meta("is_destruction_replacement", true)
	rep_node.set_meta("source_prop_id", ctx.event.definition.id)

	if staging_parent != null and is_instance_valid(staging_parent):
		staging_parent.add_child(rep_node)
	elif ctx.event.target != null and is_instance_valid(ctx.event.target) and ctx.event.target.get_parent() != null:
		ctx.event.target.get_parent().add_child(rep_node)
	return rep_node

## Alias de interfaz común para todos los consumidores de respuesta
func handle(ctx: _DestructionResponseContextScript, staging_parent: Node3D = null) -> Node3D:
	return handle_replacement(ctx, staging_parent)
