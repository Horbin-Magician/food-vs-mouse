class_name ChapterDef
extends Resource

@export var id: String = ""
@export var title: String = ""
@export var order: int = 1
@export var strategy: String = ""
@export var first_clear_reward: int = 12
@export var available: bool = false
@export var waves: Array[Resource] = []

@export var background_tint: Color = Color(0, 0, 0, 0)
