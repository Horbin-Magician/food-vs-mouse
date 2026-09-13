class_name SoundService
extends AudioStreamPlayer

var tones: Dictionary = {}

func _ready() -> void:
	max_polyphony = 4
	volume_db = -18
	for key: String in ["place","danger","clear"]:
		var wave: AudioStreamWAV = AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 22050
		var bytes: PackedByteArray = PackedByteArray()
		var length: int = 4400 if key != "clear" else 8800
		bytes.resize(length*2)
		var frequency: float = 520.0 if key == "place" else (180.0 if key == "danger" else 780.0)
		for i: int in range(length):
			var time: float = float(i)/22050.0
			var envelope: float = sin(PI * float(i)/length) * exp(-time*12.0)
			var value: int = int(sin(TAU*frequency*time)*envelope*24000)
			bytes.encode_s16(i*2,value)
		wave.data = bytes
		tones[key] = wave

func cue(key: String) -> void:
	stream = tones[key]
	play()
