extends Node
## Global signal hub (GDD §11). Mission/quest systems subscribe here later.
## Do not add gameplay logic that bypasses these signals where they apply.
##
## player_damaged is a combat *fact* and lives here; the score/power/coin
## signals are system *state* and live on ScoreManager (GDD §7 recommendation).
##
## room_cleared / run_completed are the room-progression facts (the "clear the
## room to open the doors" loop). RoomController emits them; HUD + Game listen.

@warning_ignore_start("unused_signal")
signal impact_occurred(event: ImpactEvent, damage: float)
signal entity_died(entity: Node, stats: PhysicsStats, map_id: String)
signal player_hp_changed(hp: float, max_hp: float)
signal player_damaged(amount: float)   ## emitted from Player._on_damaged
signal map_changed(map_id: String)
signal room_cleared(map_id: String)    ## a room's last mob just died → doors open
signal run_completed()                 ## the final room was cleared → win
@warning_ignore_restore("unused_signal")
