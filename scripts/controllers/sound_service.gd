class_name SoundService
extends Node

signal settings_changed
signal cue_played(id: String)

const BUS_NAMES: Array[String] = ["Master", "Music", "SFX"]
const SETTINGS_VERSION: int = 1

@export var profile: AudioProfile = preload("res://resources/audio_profile.tres")
var settings_path: String = "user://audio.cfg"
var bound_run: RunController
var context: String = ""
var muted: bool = false
var settings_error: String = ""
var levels: Dictionary[String, float] = {}
var game_paused: bool = false
var focus_ducked: bool = false
var voices: Array[AudioStreamPlayer] = []
var music_players: Array[AudioStreamPlayer] = []
var _cue_defs: Dictionary[String, AudioCueDef] = {}
var _streams: Dictionary[String, AudioStream] = {}
var _last_cue: Dictionary[String, float] = {}
var _connections: Array[Dictionary] = []
var _board: BoardController
var _combat: CombatController
var _state: RunState
var _phase: String = ""
var _wave: int = 0
var _music_target: int = -1
var _music_weights: Array[float] = [0.0, 0.0]
var _music_starts: Array[float] = [0.0, 0.0]
var _fade_elapsed: float = 0.0
var _last_tick: int = 0
var _initialized: bool = false
var _armor_remaining: Dictionary[int, int] = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_buses()
	load_settings()
	for definition: AudioCueDef in profile.cues:
		if definition.id.is_empty() or _cue_defs.has(definition.id):
			push_error("音频配置存在空 ID 或重复 ID：" + definition.id)
			continue
		_cue_defs[definition.id] = definition
		_load_stream(definition.id, definition.path, false)
	for id: String in profile.music:
		_load_stream("music_" + id, profile.music[id], true)
	for index: int in range(profile.max_voices):
		var player := AudioStreamPlayer.new()
		player.name = "Voice%d" % index
		player.bus = "SFX"
		player.set_meta("priority", -1)
		player.set_meta("gameplay", false)
		player.set_meta("started", 0)
		add_child(player)
		voices.append(player)
	for index: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "Music%d" % index
		player.bus = "Music"
		player.volume_db = -80.0
		add_child(player)
		music_players.append(player)
	_initialized = true
	_last_tick = Time.get_ticks_usec()
	var initial: String = context
	context = ""
	if not initial.is_empty(): set_context(initial)

func _exit_tree() -> void:
	_release_audio()

func _release_audio() -> void:
	_initialized = false
	_disconnect_run()
	bound_run = null
	for player: AudioStreamPlayer in voices + music_players:
		player.stop()
		player.stream = null
	_streams.clear()

func shutdown() -> void:
	# stop() releases playback on the mixer thread. Keep the main loop alive
	# briefly so it can finish before the application tears down resources.
	var references: Array[WeakRef] = []
	for stream: AudioStream in _streams.values(): references.append(weakref(stream))
	set_process(false)
	_release_audio()
	var deadline: int = Time.get_ticks_msec() + 1000
	while references.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null) and Time.get_ticks_msec() < deadline:
		await get_tree().create_timer(0.01, true, false, true).timeout

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: set_focus_ducked(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: set_focus_ducked(false)

func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var elapsed: float = maxf(0.0, float(now - _last_tick) / 1000000.0)
	_last_tick = now
	sync_run()
	advance_mix(elapsed)

func _ensure_buses() -> void:
	# AudioServer buses are global; reuse them and never remove another service's bus.
	for bus: String in BUS_NAMES:
		if AudioServer.get_bus_index(bus) >= 0: continue
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	var master: int = AudioServer.get_bus_index("Master")
	for index: int in range(AudioServer.get_bus_effect_count(master)):
		if AudioServer.get_bus_effect(master, index) is AudioEffectHardLimiter: return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = profile.limiter_ceiling_db
	AudioServer.add_bus_effect(master, limiter)

func _load_stream(id: String, path: String, looping: bool) -> void:
	if not ResourceLoader.exists(path):
		push_warning("音频资源未就绪：" + path)
		return
	var loaded: AudioStream = load(path) as AudioStream
	if loaded == null: return
	var stream: AudioStream = loaded.duplicate() as AudioStream
	if stream is AudioStreamOggVorbis: stream.loop = looping
	elif stream is AudioStreamWAV:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if looping else AudioStreamWAV.LOOP_DISABLED
	_streams[id] = stream

func cue(id: String) -> bool:
	if not _initialized or not _cue_defs.has(id) or not _streams.has(id): return false
	var definition: AudioCueDef = _cue_defs[id]
	if definition.gameplay and (game_paused or (bound_run != null and bound_run.paused)): return false
	if muted or get_level("Master") <= 0.0 or get_level("SFX") <= 0.0: return false
	var now: float = float(Time.get_ticks_usec()) / 1000000.0
	if now - _last_cue.get(id, -1000.0) < definition.cooldown: return false
	var target: AudioStreamPlayer
	for player: AudioStreamPlayer in voices:
		if not player.playing:
			target = player
			break
		if target == null or int(player.get_meta("priority")) < int(target.get_meta("priority")) or (int(player.get_meta("priority")) == int(target.get_meta("priority")) and int(player.get_meta("started")) < int(target.get_meta("started"))):
			target = player
	if target == null: return false
	if target.playing and int(target.get_meta("priority")) > definition.priority: return false
	target.stop()
	target.stream = _streams[id]
	target.volume_db = definition.gain_db + (profile.focus_gain_db if focus_ducked else 0.0)
	target.pitch_scale = 1.0
	target.set_meta("priority", definition.priority)
	target.set_meta("gameplay", definition.gameplay)
	target.set_meta("gain_db", definition.gain_db)
	target.set_meta("started", Time.get_ticks_usec())
	target.set_meta("cue_id", id)
	target.play()
	_last_cue[id] = now
	cue_played.emit(id)
	return true

func set_context(id: String) -> void:
	if not profile.music.has(id) or context == id: return
	context = id
	if not _initialized or not _streams.has("music_" + id): return
	# Two permanent players bound memory even when screens change mid-fade.
	var outgoing: int = 0 if _music_weights[0] >= _music_weights[1] else 1
	var incoming: int = 1 - outgoing
	music_players[incoming].stop()
	_music_weights[incoming] = 0.0
	_music_starts.assign(_music_weights)
	_music_target = incoming
	_fade_elapsed = 0.0
	music_players[incoming].stream = _streams["music_" + id]
	music_players[incoming].volume_db = -80.0
	music_players[incoming].pitch_scale = 1.0
	music_players[incoming].play()

func advance_mix(real_delta: float) -> void:
	if _music_target < 0 or music_players.size() != 2: return
	_fade_elapsed += maxf(0.0, real_delta)
	var fraction: float = clampf(_fade_elapsed / maxf(0.01, profile.crossfade_seconds), 0.0, 1.0)
	var duck: float = (profile.pause_gain_db if game_paused else 0.0) + (profile.focus_gain_db if focus_ducked else 0.0)
	for index: int in range(2):
		_music_weights[index] = lerpf(_music_starts[index], 1.0 if index == _music_target else 0.0, fraction)
		music_players[index].volume_db = linear_to_db(maxf(_music_weights[index], 0.0001)) + profile.music_gain_db + duck
		if fraction >= 1.0 and index != _music_target: music_players[index].stop()

func set_game_paused(value: bool) -> void:
	if game_paused == value: return
	game_paused = value
	if game_paused: _stop_gameplay()
	advance_mix(0.0)

func set_focus_ducked(value: bool) -> void:
	focus_ducked = value
	advance_mix(0.0)
	for player: AudioStreamPlayer in voices:
		if player.playing: player.volume_db = float(player.get_meta("gain_db", 0.0)) + (profile.focus_gain_db if value else 0.0)

func _stop_gameplay(keep_priority: int = 100) -> void:
	for player: AudioStreamPlayer in voices:
		if bool(player.get_meta("gameplay", false)) and int(player.get_meta("priority", -1)) < keep_priority: player.stop()

func bind_run(run: RunController = null) -> void:
	if run == bound_run and (run == null or (run.board == _board and run.combat == _combat and run.state == _state)): return
	_disconnect_run()
	_stop_gameplay()
	_last_cue.clear()
	bound_run = run
	_state = run.state if run != null else null
	_board = run.board if run != null else null
	_combat = run.combat if run != null else null
	_phase = _state.phase if _state != null else ""
	_wave = _state.global_wave() if _state != null else 0
	if run != null:
		_listen(run.changed, sync_run)
		if _board != null:
			_listen(_board.placed, _on_placed)
			_listen(_board.removed, _on_removed)
		if _combat != null:
			for unit: Dictionary in _combat.enemies: _on_spawned(unit)
			_listen(_combat.acted, _on_acted)
			_listen(_combat.damage_resolved, _on_damage)
			_listen(_combat.enemy_fallen, _on_enemy_fallen)
			_listen(_combat.food_fallen, _on_food_fallen)
			_listen(_combat.enemy_leaked, _on_leaked)
			_listen(_combat.skill_used, _on_skill)
			_listen(_combat.spawned, _on_spawned)
			if _combat.has_signal("heat_collected"):
				_listen(Signal(_combat, "heat_collected"), _on_heat_collected)
	set_game_paused(run != null and _state != null and _state.phase == "battle" and run.paused)
	if _state != null: set_context(_context_for_run())

func _listen(event: Signal, callback: Callable) -> void:
	event.connect(callback)
	_connections.append({"signal": event, "callback": callback})

func _disconnect_run() -> void:
	for connection: Dictionary in _connections:
		var event: Signal = connection.signal
		if not event.is_null() and event.is_connected(connection.callback): event.disconnect(connection.callback)
	_connections.clear()
	_armor_remaining.clear()
	_board = null
	_combat = null
	_state = null

func sync_run() -> void:
	if bound_run == null: return
	if bound_run.board != _board or bound_run.combat != _combat or bound_run.state != _state:
		bind_run(bound_run)
		return
	if _state == null: return
	set_game_paused(_state.phase == "battle" and bound_run.paused)
	if _phase != _state.phase or _wave != _state.global_wave():
		_stop_gameplay(profile.transition_keep_priority)
		if _state.phase != "battle": _armor_remaining.clear()
		if _phase == "battle" and _state.global_wave() > _wave: cue("clear")
		if _state.phase == "battle": cue("wave_start")
		_phase = _state.phase
		_wave = _state.global_wave()
		set_context(_context_for_run())

func _context_for_run() -> String:
	if _state.phase in ["won", "lost"]: return _state.phase
	if bound_run.shop.is_open(): return "shop"
	if _state.wave == 8: return "boss"
	if _state.wave == 4: return "elite"
	return "battle"

func _on_placed(_unit: Dictionary) -> void:
	cue("place")

func _on_removed(_unit: Dictionary) -> void:
	cue("remove")

func _on_acted(uid: int) -> void:
	for unit: Dictionary in _state.units:
		if unit.uid == uid:
			if unit.id in ["bun", "tea", "pepper", "popcorn", "noodles", "garlic"]: cue(unit.id)
			return
	cue("bite")

func _on_damage(unit: Dictionary, actual: float, is_food: bool, direct: bool) -> void:
	if actual <= 0.0: return
	if is_food:
		cue("hit")
	elif direct:
		# Armor is decremented before this signal, including its final protected hit.
		var armored: bool = int(unit.get("armor", 0)) >= 0 and _armor_remaining.has(unit.uid) and int(_armor_remaining[unit.uid]) > 0
		_armor_remaining[unit.uid] = int(unit.get("armor", 0))
		cue("armor" if armored else "hit")

func _on_spawned(unit: Dictionary) -> void:
	_armor_remaining[unit.uid] = int(unit.get("armor", 0))

func _on_enemy_fallen(unit: Dictionary) -> void:
	_armor_remaining.erase(unit.uid)
	cue("enemy_down")

func _on_food_fallen(_unit: Dictionary) -> void:
	cue("food_down")

func _on_leaked(_damage: int) -> void:
	var surviving: Dictionary[int, bool] = {}
	for enemy: Dictionary in _combat.enemies: surviving[enemy.uid] = true
	for uid: int in _armor_remaining.keys():
		if not surviving.has(uid): _armor_remaining.erase(uid)
	cue("danger")

func _on_heat_collected(_pickup: Dictionary) -> void:
	cue("heat_collect")

func _on_skill(id: String, _source: Dictionary, _targets: Array) -> void:
	match id:
		"produce": cue("heat_spawn")
		"flour": cue("flour")
		"summon", "reinforce": cue("summon")
		"rage": cue("rage")

func get_level(bus: String) -> float:
	return levels.get(bus, 1.0)

func set_level(bus: String, value: float) -> void:
	if bus not in BUS_NAMES or not is_finite(value): return
	levels[bus] = clampf(value, 0.0, 1.0)
	_apply_settings()
	save_settings()
	settings_changed.emit()

func set_muted(value: bool) -> void:
	muted = value
	_apply_settings()
	save_settings()
	settings_changed.emit()

func _apply_settings() -> void:
	for bus: String in BUS_NAMES:
		var index: int = AudioServer.get_bus_index(bus)
		if index < 0: continue
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(get_level(bus), 0.0001)))
		AudioServer.set_bus_mute(index, (muted if bus == "Master" else false) or get_level(bus) <= 0.0)

func load_settings() -> void:
	levels = {"Master": profile.default_master, "Music": profile.default_music, "SFX": profile.default_sfx}
	muted = false
	settings_error = ""
	var config := ConfigFile.new()
	var error: Error = config.load(settings_path)
	if error == OK and config.get_value("audio", "version", 0) == SETTINGS_VERSION:
		for bus: String in BUS_NAMES:
			var saved: Variant = config.get_value("audio", bus, levels[bus])
			if (saved is float or saved is int) and is_finite(float(saved)):
				levels[bus] = clampf(float(saved), 0.0, 1.0)
		var saved_mute: Variant = config.get_value("audio", "muted", false)
		if saved_mute is bool: muted = saved_mute
	elif error != ERR_FILE_NOT_FOUND:
		settings_error = "声音设置无法读取，已使用默认音量。"
	_apply_settings()

func save_settings() -> Error:
	var directory: String = settings_path.get_base_dir()
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error == OK:
		var config := ConfigFile.new()
		config.set_value("audio", "version", SETTINGS_VERSION)
		for bus: String in BUS_NAMES: config.set_value("audio", bus, levels[bus])
		config.set_value("audio", "muted", muted)
		error = config.save(settings_path + ".tmp")
		if error == OK: error = DirAccess.rename_absolute(settings_path + ".tmp", settings_path)
	settings_error = "" if error == OK else "声音设置保存失败，本次调整仍有效。"
	return error
