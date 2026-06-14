extends Node2D
## Root scene script. Structure (see game.tscn):
##   Game (this, group "game")
##   ├── MapHolder          ← MapManager swaps MapBase instances here
##   ├── Player             ← persistent; reparented into each map's entity layer
##   ├── FeedbackManager    ← hit-stop / shake / sfx (EventBus-driven)
##   └── HUD                ← CanvasLayer HP bar

func _ready() -> void:
	add_to_group("game")
	# Deferred so the player's _ready (camera setup) runs before the first
	# map load reparents it.
	MapManager.start.call_deferred("overworld_a", "default")
