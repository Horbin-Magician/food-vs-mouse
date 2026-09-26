class_name AudioCueDef
extends Resource

@export var id: String = ""
@export_file("*.wav", "*.ogg") var path: String = ""
@export var gain_db: float = -8.0
@export var cooldown: float = 0.1
@export var priority: int = 1
@export var gameplay: bool = true
