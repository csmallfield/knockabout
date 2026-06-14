class_name WeaponProfile
extends Resource
## Attack-as-data (D5). The player's attack reads ONLY from this resource;
## inventory/equipment later just swaps resources. Visuals included so a
## spear and a club differ by .tres alone.

enum KnockbackMode { RADIAL, TANGENTIAL }   # away from wielder / along the swing
enum SwingPattern { ALTERNATE, FIXED }

@export_group("Impact")
@export var flat_damage := 10.0
@export var impulse := 24000.0          # mass·px/s
@export var velocity_inherit := 0.3     # fraction of wielder velocity (toward target) added
@export var knockback_mode := KnockbackMode.RADIAL

@export_group("Sweep")
@export var arc_degrees := 100.0        # centered on facing
@export var range_px := 44.0            # blade tip, from wielder center
@export var blade_length := 32.0        # contact volume length, back from the tip
@export var active_frames := 6          # 0.1 s at 60 tps
@export var cooldown := 0.45
@export var swing_pattern := SwingPattern.ALTERNATE

@export_group("Visual")
@export var color := Color(0.5, 0.36, 0.2)
@export var shaft_width := 5.0
@export var head_radius := 5.0

## D5 hook: array of {hold_time, impulse_mult, damage_mult} dictionaries.
## Empty for the prototype; swing code reads the reached level when populated.
@export var charge_levels: Array[Dictionary] = []
