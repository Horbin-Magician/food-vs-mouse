class_name DifficultyDef
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var hp_multiplier: float = 1.0
@export var damage_multiplier: float = 1.0

@export var reward_multiplier: float = 1.0
@export var inspiration_drop_chance: float = 0.0

func reward(base: int) -> int:
	return roundi(base * reward_multiplier)
