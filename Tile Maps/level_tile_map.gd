class_name LevelTileMap
extends TileMap

## 获取地图的边界范围（用于相机限制）
func GetTilemapBounds() -> Array[Vector2]:
	var bounds: Array[Vector2] = []
	var used_cells = get_used_cells(0)
	
	if used_cells.is_empty():
		return bounds
	
	# 获取所有使用的地块的范围
	var min_pos = used_cells[0]
	var max_pos = used_cells[0]
	
	for cell in used_cells:
		min_pos.x = min(min_pos.x, cell.x)
		min_pos.y = min(min_pos.y, cell.y)
		max_pos.x = max(max_pos.x, cell.x)
		max_pos.y = max(max_pos.y, cell.y)
	
	# 转换为世界坐标
	var top_left = map_to_local(min_pos)
	var bottom_right = map_to_local(max_pos) + get_tileset().tile_size
	
	bounds.append(top_left)
	bounds.append(bottom_right)
	
	return bounds


## 设置相机限制
func SetCameraLimits(camera: Camera2D) -> void:
	if camera == null:
		push_error("Camera2D 为空")
		return
	
	var bounds = GetTilemapBounds()
	if bounds.is_empty():
		push_error("TileMap 没有可用的地块")
		return
	
	var top_left = bounds[0]
	var bottom_right = bounds[1]
	
	# 获取视口大小
	var viewport_size = get_viewport_rect().size / get_viewport().canvas_transform.get_scale()
	
	# 计算相机限制
	camera.limit_left = int(top_left.x)
	camera.limit_top = int(top_left.y)
	camera.limit_right = int(bottom_right.x)
	camera.limit_bottom = int(bottom_right.y)


# 当节点进入场景树时调用
func _ready() -> void:
	# 查找场景中的相机
	var camera = get_tree().root.get_camera_2d()
	
	if camera != null:
		SetCameraLimits(camera)
	else:
		push_warning("场景中未找到 Camera2D")
