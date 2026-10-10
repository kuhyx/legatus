class_name AudioFake
extends RefCounted
## Synthetic sound for the audio tests: the real samples are downloaded, not
## in git, so the tests must not depend on them.


## 0.1 s of 16-bit silence.
static func silent_stream() -> AudioStreamWAV:
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var data: PackedByteArray = PackedByteArray()
	if data.resize(2205 * 2) != OK:
		return null
	wav.data = data
	return wav


## A bank where every one-shot list and loop is one silent stream.
static func bank() -> AudioBank:
	var sounds: AudioBank = AudioBank.new()
	var one: Array[AudioStream] = [silent_stream()]
	sounds.hooves = one
	sounds.creaks = one
	sounds.snorts = one
	sounds.clashes = one
	sounds.wind = silent_stream()
	sounds.crowd = silent_stream()
	return sounds
