class_name ExitArea
extends Area2D
## Map exit / door (GDD §9.1, §8.3). auto_trigger=true: edge exits fire on
## body overlap. false: doors fire via the player's interact scanner.

@export var target_map_id := ""
@export var target_spawn_id := "default"
@export var auto_trigger := true
var size_px := Vector2(32, 32)

func _ready() -> void:
	collision_layer = Tuning.L_INTERACT
	collision_mask = Tuning.L_PLAYER if auto_trigger else 0
	add_child(EntityKit.rect_collider(size_px))
	if auto_trigger:
		body_entered.connect(func(body: Node) -> void:
			if body.is_in_group("player"):
				trigger(body))

func trigger(_who: Node) -> void:
	MapManager.change_map(target_map_id, target_spawn_id)
