extends Node

signal TileMapBoundsChanged(bounds: Array[Vector2])

var current_tilemap_bounds: Array[Vector2] = []


func _ready() -> void:
	call_deferred("RefreshCurrentTilemapBounds")


func RefreshCurrentTilemapBounds() -> void:
	var world_bounds: Rect2 = GetTileMapWorldBounds()
	if world_bounds.size == Vector2.ZERO:
		current_tilemap_bounds.clear()
		return

	SetCurrentTilemapBounds([
		world_bounds.position,
		world_bounds.position + world_bounds.size,
	])


func SetCurrentTilemapBounds(bounds: Array[Vector2]) -> void:
	if bounds.size() < 2:
		current_tilemap_bounds.clear()
		return

	current_tilemap_bounds = bounds.duplicate()
	TileMapBoundsChanged.emit(current_tilemap_bounds)


func GetTileMapWorldBounds() -> Rect2:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return Rect2()

	var tile_map_layers: Array[TileMapLayer] = []
	CollectTileMapLayers(scene_root, tile_map_layers)

	var has_bounds: bool = false
	var world_bounds: Rect2 = Rect2()
	for tile_map_layer in tile_map_layers:
		if tile_map_layer == null or tile_map_layer.tile_set == null:
			continue

		var used_rect: Rect2i = tile_map_layer.get_used_rect()
		if used_rect.size == Vector2i.ZERO:
			continue

		var tile_size: Vector2 = Vector2(tile_map_layer.tile_set.tile_size)
		var top_left_local: Vector2 = tile_map_layer.map_to_local(used_rect.position) - tile_size * 0.5
		var bottom_right_cell: Vector2i = used_rect.position + used_rect.size - Vector2i.ONE
		var bottom_right_local: Vector2 = tile_map_layer.map_to_local(bottom_right_cell) + tile_size * 0.5
		var top_left_world: Vector2 = tile_map_layer.to_global(top_left_local)
		var bottom_right_world: Vector2 = tile_map_layer.to_global(bottom_right_local)
		var layer_bounds: Rect2 = Rect2(top_left_world, Vector2.ZERO).expand(bottom_right_world)

		if not has_bounds:
			world_bounds = layer_bounds
			has_bounds = true
		else:
			world_bounds = world_bounds.merge(layer_bounds)

	return world_bounds if has_bounds else Rect2()


func CollectTileMapLayers(node: Node, into: Array[TileMapLayer]) -> void:
	if node is TileMapLayer:
		into.append(node as TileMapLayer)

	for child in node.get_children():
		CollectTileMapLayers(child, into)