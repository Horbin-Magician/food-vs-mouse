class_name ProgressionDef
extends Resource

@export var loadout_limit: int = 5
@export var max_level: int = 10
@export var shop_slots: int = 4
@export var card_price: int = 4
@export var refresh_base: int = 2
@export var refresh_limit: int = 30
@export var inspiration_rewards: Array[int] = [4, 5, 6, 8, 8, 10, 12, 16]
@export var stat_per_level: float = 0.05
@export var production_per_level: float = 0.02
@export var material_base: float = 0.6
@export var material_decay: float = 0.9
@export var protected_target: int = 6
