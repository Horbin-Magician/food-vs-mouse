class_name AudioProfile
extends Resource

@export var cues: Array[AudioCueDef] = []
@export var music: Dictionary[String, String] = {}
@export var music_gain_db: float = -3.0
@export var crossfade_seconds: float = 0.75
@export var max_voices: int = 12
@export var limiter_ceiling_db: float = -1.0
@export var transition_keep_priority: int = 4
@export var pause_gain_db: float = -9.0
@export var focus_gain_db: float = -12.0
@export var default_master: float = 0.8
@export var default_music: float = 0.7
@export var default_sfx: float = 0.85
