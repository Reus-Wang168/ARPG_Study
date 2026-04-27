class_name PlayerHud
extends CanvasLayer

const PlayerScript = preload("res://Player/Scripst/player.gd")
const GuiHealthTexture = preload("res://Assets/gui-health.png")

const LIFE_REGION: Rect2 = Rect2(29, 0, 34, 8)
const HEART_REGION: Rect2 = Rect2(0, 0, 9, 8)
const LABEL_SIZE: Vector2 = Vector2(34, 8)
const HEART_SIZE: Vector2 = Vector2(9, 8)

@export_range(1.0, 8.0, 0.25) var hud_scale: float = 2.0
@export var margin_top_right: Vector2 = Vector2(18, 8)
@export_range(0.0, 12.0, 0.5) var heart_spacing: float = 0.0
@export_range(0.0, 12.0, 0.5) var label_row_gap: float = 1.0
@export var empty_heart_modulate: Color = Color(0.36, 0.34, 0.46, 0.45)

@onready var root: Control = $Root

var player: PlayerScript
var life_label: TextureRect
var heart_rects: Array[TextureRect] = []


func _ready() -> void:
	BuildHudPieces()
	ResolvePlayer()


func BuildHudPieces() -> void:
	if root == null:
		return

	for child in root.get_children():
		child.queue_free()

	heart_rects.clear()
	life_label = TextureRect.new()
	life_label.texture = BuildAtlasTexture(LIFE_REGION)
	life_label.scale = Vector2.ONE * hud_scale
	life_label.position = Vector2.ZERO
	life_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	life_label.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(life_label)


func ResolvePlayer() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var player_node: PlayerScript = node as PlayerScript
		if player_node == null:
			continue

		BindPlayer(player_node)
		return

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		call_deferred("ResolvePlayer")
		return

	BindPlayer(scene_root.find_child("Player", true, false) as PlayerScript)


func BindPlayer(player_node: PlayerScript) -> void:
	if player == player_node:
		return

	if player != null and player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.disconnect(_on_player_health_changed)

	player = player_node
	if player == null:
		return

	if not player.health_changed.is_connected(_on_player_health_changed):
		player.health_changed.connect(_on_player_health_changed)

	UpdateHud(player.GetCurrentHealth(), player.GetMaxHealth())


func UpdateHud(current_health: int, max_health: int) -> void:
	if root == null:
		return

	var heart_count: int = maxi(max_health, 0)
	EnsureHeartSlots(heart_count)

	for heart_index in range(heart_rects.size()):
		heart_rects[heart_index].modulate = Color.WHITE if heart_index < current_health else empty_heart_modulate

	UpdateRootLayout(heart_count)


func EnsureHeartSlots(heart_count: int) -> void:
	while heart_rects.size() < heart_count:
		var heart_rect := TextureRect.new()
		heart_rect.texture = BuildAtlasTexture(HEART_REGION)
		heart_rect.scale = Vector2.ONE * hud_scale
		heart_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		heart_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(heart_rect)
		heart_rects.append(heart_rect)

	while heart_rects.size() > heart_count:
		var heart_rect: TextureRect = heart_rects.pop_back()
		heart_rect.queue_free()


func UpdateRootLayout(heart_count: int) -> void:
	var scaled_label_size: Vector2 = LABEL_SIZE * hud_scale
	var scaled_heart_size: Vector2 = HEART_SIZE * hud_scale
	var scaled_heart_spacing: float = heart_spacing * hud_scale
	var scaled_row_gap: float = label_row_gap * hud_scale
	var heart_row_width: float = 0.0
	if heart_count > 0:
		heart_row_width = scaled_heart_size.x * heart_count + scaled_heart_spacing * (heart_count - 1)

	var hud_width: float = maxf(scaled_label_size.x, heart_row_width)
	var hearts_start_x: float = floorf((hud_width - heart_row_width) * 0.5)
	var label_x: float = floorf((hud_width - scaled_label_size.x) * 0.5)
	var hearts_y: float = scaled_label_size.y + scaled_row_gap
	var hud_height: float = hearts_y + scaled_heart_size.y if heart_count > 0 else scaled_label_size.y

	if life_label != null:
		life_label.scale = Vector2.ONE * hud_scale
		life_label.position = Vector2(label_x, 0)

	for heart_index in range(heart_rects.size()):
		var heart_rect: TextureRect = heart_rects[heart_index]
		heart_rect.scale = Vector2.ONE * hud_scale
		heart_rect.position = Vector2(
			hearts_start_x + (scaled_heart_size.x + scaled_heart_spacing) * heart_index,
			hearts_y
		)

	root.anchor_left = 1.0
	root.anchor_top = 0.0
	root.anchor_right = 1.0
	root.anchor_bottom = 0.0
	root.offset_left = -margin_top_right.x - hud_width
	root.offset_top = margin_top_right.y
	root.offset_right = -margin_top_right.x
	root.offset_bottom = margin_top_right.y + hud_height


func BuildAtlasTexture(region: Rect2) -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = GuiHealthTexture
	atlas_texture.region = region
	return atlas_texture


func _on_player_health_changed(current_health: int, max_health: int) -> void:
	UpdateHud(current_health, max_health)