class_name EnemyDef
extends Resource

@export var id: String = ""
@export var title: String = ""
@export_enum("normal", "elite", "boss") var rank: String = "normal"
@export var behavior_id: String = "legacy"
@export var art_id: String = ""
@export var hint: String = ""
@export_multiline var description: String = ""
@export_multiline var story: String = ""
@export var stats: Dictionary = {}
@export var skills: Dictionary = {}
