class_name ChargeLevel
extends Resource
## One tier of a charged attack (D5). The reached tier scales the swing's
## damage/impulse and the player's move speed while winding up. Tiers are read
## in ascending hold_time order; the base (uncharged) swing is the implicit
## level -1 with all mults 1.0.

@export var hold_time := 0.35    ## seconds of charge needed to reach this tier
@export var damage_mult := 1.0   ## × weapon flat_damage on the swing
@export var impulse_mult := 1.0  ## × weapon impulse on the swing
@export var move_mult := 0.5     ## player move-speed scalar while at this tier