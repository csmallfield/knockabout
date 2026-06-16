class_name LootTable
extends Resource
## Per-mob drop spec, referenced from MobProfile (GDD §2.2). Coins roll
## independently of the weighted "special" slot, so a mob can reliably drop a
## coin *and* sometimes a buff.

@export var coin_min := 0
@export var coin_max := 2
@export var drop_chance := 0.35          ## P(any special drop)
@export var drops: Array[LootDrop] = []  ## weighted special entries
