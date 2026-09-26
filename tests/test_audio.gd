extends SceneTree

# Silence fixtures exercise real AudioStreamPlayer scheduling without depending on
# speakers or spending test time decoding every production track.
class FixtureSound extends SoundService:
	func _load_stream(id: String, _path: String, looping: bool) -> void:
		var wave := AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 22050
		var bytes := PackedByteArray()
		bytes.resize(44100)
		wave.data = bytes
		if looping:
			wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wave.loop_end = 22050
		_streams[id] = wave

var played: Array[String] = []

func _init() -> void:
	call_deferred("check")

func clear_cues(sound: SoundService) -> void:
	for player: AudioStreamPlayer in sound.voices: player.stop()
	sound._last_cue.clear()
	played.clear()

func check() -> void:
	var folder: String = "/tmp/food_vs_mouse_audio_%d" % Time.get_ticks_usec()
	var sound := FixtureSound.new()
	sound.settings_path = folder.path_join("audio.cfg")
	sound.profile = sound.profile.duplicate(true)
	sound.profile.max_voices = 3
	root.add_child(sound)
	sound.set_process(false)
	sound.cue_played.connect(func(id: String) -> void: played.append(id))
	assert(sound.voices.size() == 3 and sound.music_players.size() == 2)
	assert(sound._cue_defs.size() == 28 and sound.profile.music.size() == 7)
	var buses: int = AudioServer.bus_count
	var effects: int = AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Master"))
	assert(AudioServer.get_bus_effect(AudioServer.get_bus_index("Master"), effects - 1) is AudioEffectHardLimiter)
	assert(sound.cue("hit"))
	assert(not sound.cue("hit"))
	assert(not sound.cue("missing"))
	assert(sound.cue("bite") and sound.cue("bun"))
	assert(sound.cue("danger"))
	assert(sound.voices.any(func(player: AudioStreamPlayer) -> bool: return player.get_meta("cue_id", "") == "danger"))
	clear_cues(sound)
	for id: String in ["danger", "rage", "wave_start"]: assert(sound.cue(id))
	assert(not sound.cue("hit"))
	assert(sound.get_child_count() == 5)
	clear_cues(sound)

	# Same context cannot restart; repeated mid-fade transitions stay bounded.
	sound.set_context("menu")
	var target: int = sound._music_target
	var stream: AudioStream = sound.music_players[target].stream
	sound.advance_mix(0.4)
	var fade: float = sound._fade_elapsed
	sound.set_context("menu")
	assert(sound._music_target == target and sound.music_players[target].stream == stream)
	assert(sound._fade_elapsed == fade)
	for index: int in range(70):
		sound.set_context(["shop", "battle", "elite", "boss", "won", "lost", "menu"][index % 7])
		sound.advance_mix(0.04)
	assert(sound.music_players.size() == 2 and sound.get_child_count() == 5)
	sound.advance_mix(1.0)
	assert(sound.music_players.filter(func(player: AudioStreamPlayer) -> bool: return player.playing).size() == 1)
	var base: float = sound.music_players[sound._music_target].volume_db
	assert(sound.cue("bun"))
	sound.set_game_paused(true)
	assert(not sound.voices.any(func(player: AudioStreamPlayer) -> bool: return player.playing))
	assert(not sound.cue("bun") and sound.cue("ui_click"))
	assert(is_equal_approx(sound.music_players[sound._music_target].volume_db, base + sound.profile.pause_gain_db))
	var player_level: float = sound.get_level("Music")
	sound.set_focus_ducked(true)
	assert(sound.get_level("Music") == player_level)
	assert(is_equal_approx(sound.music_players[sound._music_target].volume_db, base + sound.profile.pause_gain_db + sound.profile.focus_gain_db))
	sound.set_focus_ducked(false)
	sound.set_game_paused(false)
	assert(is_equal_approx(sound.music_players[sound._music_target].volume_db, base))

	var run := RunController.new()
	run.new_run(41)
	clear_cues(sound)
	sound.bind_run(run)
	assert(sound.context == "battle" and played.is_empty() and not run.shop.is_open())
	var random_state: int = run.rng.state
	run.advance(0.0)
	assert(sound.context == "battle" and played == ["wave_start"])
	assert(run.rng.state != random_state) # WaveDirector.begin owns gameplay RNG.
	random_state = run.rng.state
	clear_cues(sound)
	assert(run.board.place("bun", 0, 0, false).is_empty())
	assert(played == ["place"])
	clear_cues(sound)
	run.combat.acted.emit(run.state.units[0].uid)
	assert(played == ["bun"])
	assert(run.rng.state == random_state)
	run.speed = 2.0
	assert(sound.voices.all(func(player: AudioStreamPlayer) -> bool: return player.pitch_scale == 1.0))
	assert(sound.music_players.all(func(player: AudioStreamPlayer) -> bool: return player.pitch_scale == 1.0))
	clear_cues(sound)
	run.combat.spawn("lid", 0, run.data.waves[0])
	var enemy: Dictionary = run.combat.enemies[-1]
	for index: int in range(int(enemy.armor)):
		clear_cues(sound)
		run.combat.damage_enemy(enemy, 1.0, "bun")
		assert(played == ["armor"]) # Includes the final protected hit.
	clear_cues(sound)
	run.combat.damage_enemy(enemy, 1.0, "bun")
	assert(played == ["hit"])
	clear_cues(sound)
	enemy.x = -10.0
	run.combat.step(0.001)
	assert(played == ["danger"] and not sound._armor_remaining.has(enemy.uid))
	run.state.phase = "lost"
	run.paused = true
	sound.sync_run()
	assert(not sound.game_paused and sound.voices.any(func(player: AudioStreamPlayer) -> bool: return player.playing and player.get_meta("cue_id", "") == "danger"))
	sound.set_game_paused(true)
	assert(not sound.voices.any(func(player: AudioStreamPlayer) -> bool: return player.playing))
	run.state.phase = "battle"
	run.paused = false
	sound.sync_run()
	clear_cues(sound)
	run.combat.produce_heat(run.state.units[0])
	assert(played == ["heat_spawn"])
	assert(run.combat.collect_heat(run.combat.heat_pickups[0].uid))
	assert(played == ["heat_spawn", "heat_collect"])
	assert(not run.combat.collect_heat(run.combat.heat_pickups[0].uid))
	assert(played.size() == 2)
	clear_cues(sound)
	target = sound._music_target
	run.finish_wave()
	sound.sync_run()
	assert(sound.context == "battle" and played == ["clear"] and not run.shop.is_open())
	assert(sound._music_target == target, "ordinary clear keeps the current battle track")
	sound.sync_run()
	assert(played.size() == 1)
	clear_cues(sound)
	run.advance(0.0)
	assert(sound.context == "battle" and played == ["wave_start"])
	assert(sound._music_target == target)
	run.state.phase = "prepare"
	run.state.wave = 4
	sound.sync_run()
	assert(sound.context == "elite", "ordinary elite prepare uses battle music")
	run.start()
	assert(sound.context == "elite")
	run.state.phase = "prepare"
	run.state.wave = 8
	sound.sync_run()
	assert(sound.context == "boss", "ordinary boss prepare uses battle music")
	run.start()
	assert(sound.context == "boss")
	run.finish_wave()
	sound.sync_run()
	assert(sound.context == "shop" and run.state.chapter_id == "kitchen_2")
	run.state.chapter_id = "kitchen_5"
	run.state.wave = 8
	run.start()
	assert(sound.context == "boss")
	run.finish_wave()
	sound.sync_run()
	assert(sound.context == "won")

	var old_board: BoardController = run.board
	var old_combat: CombatController = run.combat
	run.new_run(42)
	assert(sound.context == "battle" and sound._armor_remaining.is_empty())
	assert(not old_board.placed.is_connected(sound._on_placed))
	assert(not old_combat.skill_used.is_connected(sound._on_skill))
	clear_cues(sound)
	old_board.placed.emit({})
	old_combat.acted.emit(1)
	assert(played.is_empty())
	run.start()
	clear_cues(sound)
	run.paused = true
	assert(not sound.cue("bun")) # Suppress immediately, before the next frame sync.
	sound.sync_run()
	assert(sound.game_paused)
	run.paused = false
	sound.sync_run()

	# Persistence is isolated from profiles and validates each saved field.
	sound.set_level("Music", 0.31)
	sound.set_level("SFX", -1.0)
	assert(sound.get_level("SFX") == 0.0)
	sound.set_level("SFX", 0.6)
	sound.set_level("Master", INF)
	assert(is_equal_approx(sound.get_level("Master"), sound.profile.default_master))
	sound.set_muted(true)
	assert(not sound.cue("ui_click") and AudioServer.is_bus_mute(AudioServer.get_bus_index("Master")))
	sound.set_muted(false)
	assert(sound.save_settings() == OK)
	var second := FixtureSound.new()
	second.settings_path = sound.settings_path
	root.add_child(second)
	second.set_process(false)
	assert(AudioServer.bus_count == buses and AudioServer.get_bus_effect_count(AudioServer.get_bus_index("Master")) == effects)
	assert(is_equal_approx(second.get_level("Music"), 0.31) and is_equal_approx(second.get_level("SFX"), 0.6))
	second.free()

	var dialog := AudioSettings.new()
	root.add_child(dialog)
	dialog.setup(sound)
	dialog.open(run)
	assert(dialog.visible and run.paused and sound.game_paused)
	dialog.sliders.Music.value = 47
	assert(is_equal_approx(sound.get_level("Music"), 0.47))
	dialog.hide()
	assert(not run.paused and not sound.game_paused)
	run.paused = true
	dialog.open(run)
	dialog.hide()
	assert(run.paused)
	run.paused = false
	dialog.open(run)
	run.new_run(43)
	dialog.hide()
	assert(not run.paused and sound.context == "battle")
	run.start()
	dialog.open(run)
	sound.bind_run(null)
	dialog.hide()
	assert(run.paused) # A detached game must never be resumed by an old dialog.
	dialog.free()

	var invalid := ConfigFile.new()
	invalid.set_value("audio", "version", 1)
	invalid.set_value("audio", "Music", "invalid")
	invalid.set_value("audio", "SFX", 4.0)
	invalid.set_value("audio", "muted", "invalid")
	assert(invalid.save(sound.settings_path) == OK)
	sound.load_settings()
	assert(sound.get_level("Music") == sound.profile.default_music and sound.get_level("SFX") == 1.0 and not sound.muted)
	invalid.set_value("audio", "version", 999)
	assert(invalid.save(sound.settings_path) == OK)
	sound.load_settings()
	assert(not sound.settings_error.is_empty())
	sound.settings_path = folder.path_join("audio.cfg/blocked.cfg")
	assert(sound.save_settings() != OK and not sound.settings_error.is_empty())
	sound.free()
	# Production assets must resolve through the same runtime path used by exports.
	var production := SoundService.new()
	production.settings_path = folder.path_join("production.cfg")
	root.add_child(production)
	production.set_process(false)
	assert(production._streams.size() == 35)
	for id: String in production._streams:
		assert(production._streams[id].get_length() > 0.0)
	for id: String in production.profile.music:
		assert(production._streams["music_" + id] is AudioStreamOggVorbis)
		assert(production._streams["music_" + id].loop)
	production.free()
	assert(AudioServer.bus_count == buses)
	DirAccess.remove_absolute(folder.path_join("audio.cfg"))
	DirAccess.remove_absolute(folder)
	await process_frame
	await create_timer(0.5).timeout
	print("PASS audio: cue routing, armor, pickup, cooldown, voice priorities, bounded music, ducking, RNG, lifecycle, settings and dialog pause ownership")
	quit()
