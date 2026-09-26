extends SceneTree

var heard: Array[String] = []
var folder: String

func _init() -> void:
	call_deferred("check")

func services(node: Node) -> int:
	var total: int = 1 if node is SoundService else 0
	for child: Node in node.get_children(): total += services(child)
	return total

func clear_cues(sound: SoundService) -> void:
	for player: AudioStreamPlayer in sound.voices: player.stop()
	sound._last_cue.clear()
	heard.clear()

func open_front() -> Node:
	var front: Node = load("res://scenes/front_end.tscn").instantiate()
	root.add_child(front)
	front.saves.folder = folder
	front.sound.settings_path = folder.path_join("audio.cfg")
	front.sound.load_settings()
	front.audio_settings.setup(front.sound)
	front.sound.cue_played.connect(func(id: String) -> void: heard.append(id))
	front.show_menu()
	return front

func check() -> void:
	folder = "user://qa_audio_flow_%d/" % Time.get_ticks_usec()
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	var front := open_front()
	var sound: SoundService = front.sound
	assert(services(front) == 1 and sound.get_parent() == front)
	assert(sound.context == "menu" and sound.bound_run == null)
	assert(sound.music_players.size() == 2 and (sound.music_players[0].playing or sound.music_players[1].playing))
	front.audio_button.pressed.emit()
	assert(front.audio_settings.visible)
	front.audio_settings.sliders.Master.value = 73
	front.audio_settings.sliders.Music.value = 36
	front.audio_settings.sliders.SFX.value = 58
	assert(sound.settings_error.is_empty())
	assert(is_equal_approx(sound.get_level("Master"),0.73))
	assert(is_equal_approx(sound.get_level("Music"),0.36))
	assert(is_equal_approx(sound.get_level("SFX"),0.58))
	front.audio_settings.hide()
	front.show_hub("shop")
	assert(front.hub.sound == sound and sound.context == "shop")
	heard.clear()
	front.hub.rebuild()
	assert(heard.is_empty())
	front.start_new()
	var old_run: RunController = front.game.run
	assert(front.game.sound == sound and services(front) == 1)
	assert(sound.bound_run == old_run and sound.context == "battle")
	assert(old_run.state.phase == "battle" and not old_run.shop.is_open())
	assert("place" not in heard and "clear" not in heard)
	heard.clear()
	front.game.finish_shopping()
	assert(sound.context == "battle" and heard.is_empty(), "shopping action cannot restart a new battle")
	assert(old_run.board.place("bun",2,0,false).is_empty())
	assert("place" in heard)
	heard.clear()
	old_run.finish_wave()
	sound.sync_run()
	assert(sound.context == "battle" and heard == ["clear"])
	assert(old_run.state.units.size() == 1)
	clear_cues(sound)
	old_run.advance(0.0)
	assert(sound.context == "battle" and heard == ["wave_start"])
	front.show_menu()
	assert(sound.bound_run == null and sound.context == "menu")
	heard.clear()
	front.continue_run()
	var run: RunController = front.game.run
	assert(run != old_run and sound.bound_run == run)
	assert(run.state.units.size() == 1 and run.state.phase == "battle")
	assert(sound.context == "battle" and heard.is_empty())
	# Retained old controllers cannot reach the persistent audio service.
	old_run.board.placed.emit(old_run.state.units[0])
	old_run.combat.enemy_leaked.emit(1)
	old_run.state.phase = "lost"
	old_run.changed.emit()
	assert(heard.is_empty() and sound.context == "battle")
	front.game.finish_shopping()
	assert(sound.context == "battle")
	front.game.speed_button.pressed.emit()
	assert(run.speed == 2.0)
	sound.sync_run()
	for player: AudioStreamPlayer in sound.music_players: assert(player.pitch_scale == 1.0)
	front.audio_button.pressed.emit()
	assert(front.audio_settings.visible and run.paused and sound.game_paused)
	var elapsed: float = run.state.elapsed
	run.advance(0.25)
	assert(run.state.elapsed == elapsed)
	front.audio_settings.hide()
	assert(not run.paused and not sound.game_paused)
	run.paused = true
	front.audio_button.pressed.emit()
	front.audio_settings.hide()
	assert(run.paused and sound.game_paused)
	run.paused = false
	run.state.wave = 4
	run.changed.emit()
	assert(sound.context == "elite")
	front.audio_button.pressed.emit()
	assert(run.paused)
	# A result shown while settings are open must not revive the previous battle.
	run.state.phase = "lost"
	run.changed.emit()
	front._process(0)
	assert(front.showing_result and sound.context == "lost")
	assert(not front.audio_settings.visible and run.paused)
	assert(not sound.game_paused)
	front.leave_result("new")
	assert(front.game == null and sound.bound_run == null and sound.context == "shop")
	front.start_new()
	assert(front.game.sound == sound and services(front) == 1)
	for index: int in range(7):
		front.game.run.advance(0.0)
		front.game.run.finish_wave()
		sound.sync_run()
		assert(sound.context != "shop")
	clear_cues(sound)
	front.game.run.advance(0.0)
	assert(sound.context == "boss")
	front.game.run.finish_wave()
	sound.sync_run()
	front._process(0)
	assert(not front.showing_result and sound.context == "shop")
	assert(front.game.run.state.chapter_id == "kitchen_2" and heard.count("clear") == 1, "Cross-chapter cue: %s / %s" % [front.game.run.state.chapter_id,str(heard)])
	front.show_menu()
	clear_cues(sound)
	front.continue_run()
	assert(front.game.run.shop.is_open() and sound.context == "shop")
	assert(heard.is_empty(), "resuming the chapter shop does not replay its clear cue")
	var shops: int = 0
	for index: int in range(32):
		if front.game.run.shop.is_open():
			shops += 1
			assert(sound.context == "shop")
			front.game.finish_shopping()
		else:
			front.game.run.advance(0.0)
		front.game.run.finish_wave()
		sound.sync_run()
	assert(shops == 4)
	sound.sync_run()
	front._process(0)
	assert(front.showing_result and sound.context == "won")
	front.leave_result("menu")
	assert(sound.context == "menu" and sound.bound_run == null)
	front.audio_button.pressed.emit()
	front.audio_settings.mute_button.button_pressed = true
	assert(sound.muted)
	front.audio_settings.hide()
	front.queue_free()
	await process_frame
	assert(not is_instance_valid(sound))
	front = open_front()
	sound = front.sound
	assert(services(front) == 1 and sound.muted)
	assert(is_equal_approx(sound.get_level("Master"),0.73))
	assert(is_equal_approx(sound.get_level("Music"),0.36))
	assert(is_equal_approx(sound.get_level("SFX"),0.58))
	assert(front.audio_settings.sliders.Master.value == 73)
	assert(front.audio_settings.sliders.Music.value == 36)
	assert(front.audio_settings.sliders.SFX.value == 58)
	front.queue_free()
	await process_frame
	# Give the audio mixer time to release the final streaming playback.
	await create_timer(0.5).timeout
	print("PASS audio flow: shared service, seven music contexts, four chapter shops, ordinary battle continuity, resume silence, old-run disconnect, settings pause/results, 2x pitch and persisted sliders/mute")
	quit()
