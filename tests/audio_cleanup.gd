extends RefCounted

# Godot's stop() queues a short fade on the audio thread; a later main-thread
# update releases its playback references. Assert actual release before quitting
# short UI tests instead of racing that queue or adding an unconditional delay.
static func streams(sound: SoundService) -> Array[WeakRef]:
	var references: Array[WeakRef] = []
	for stream: AudioStream in sound._streams.values(): references.append(weakref(stream))
	return references

static func release_scene(scene: Node, tree: SceneTree) -> void:
	var references: Array[WeakRef] = streams(scene.sound)
	scene.queue_free()
	await tree.process_frame
	var deadline: int = Time.get_ticks_msec() + 1000
	while references.any(func(reference: WeakRef) -> bool: return reference.get_ref() != null) and Time.get_ticks_msec() < deadline:
		await tree.create_timer(0.01, true, false, true).timeout
	assert(not is_instance_valid(scene), "Audio scene was not freed")
	assert(references.all(func(reference: WeakRef) -> bool: return reference.get_ref() == null), "AudioServer retained stopped audio resources for more than one second")
