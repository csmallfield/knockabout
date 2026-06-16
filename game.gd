extends Node2D
## Root scene script. Structure (see game.tscn):
##   Game (this, group "game")
##   ├── MapHolder          ← MapManager swaps MapBase instances here
##   ├── Player             ← persistent; reparented into each map's entity layer
##   ├── FeedbackManager    ← hit-stop / shake / sfx (EventBus-driven)
##   ├── HUD                ← CanvasLayer HP / score / power / room status
##   └── RunOverlay         ← victory screen + restart (built here)

const START_ROOM := "room_01"

var _overlay: RunOverlay

func _ready() -> void:
	add_to_group("game")

	_overlay = RunOverlay.new()
	add_child(_overlay)
	_overlay.restart_requested.connect(_restart_run)
	EventBus.run_completed.connect(_on_run_completed)

	# Deferred so the player's _ready (camera setup) runs before the first
	# map load reparents it.
	MapManager.start.call_deferred(START_ROOM, "default")

func _on_run_completed() -> void:
	# Deferred: run_completed fires inside the dying mob's entity_died callback
	# (during physics). Pausing the tree from there can wedge the frame, so we
	# show on the next idle frame instead.
	_show_victory_deferred.call_deferred()

func _show_victory_deferred() -> void:
	_overlay.show_victory(int(round(ScoreManager.score)), WorldState.get_coins())

func _restart_run() -> void:
	WorldState.reset_run()      # wipe room-clear flags, destruction, coins
	ScoreManager.reset_run()    # wipe score / power / meter
	_overlay.hide_overlay()
	MapManager.change_map(START_ROOM, "default")
