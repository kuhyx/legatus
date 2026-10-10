class_name VoicePool
extends Node3D
## A few players taking turns (round robin) for overlapping one-shots: each
## hit gets its own stream, pitch and volume, which one polyphonic player
## cannot give (its pitch_scale and volume_db are shared by every voice).
## Positional pools (AudioStreamPlayer3D) sound from this node's position.

var _flat: Array[AudioStreamPlayer] = []
var _spatial: Array[AudioStreamPlayer3D] = []
var _next: int = 0


## `voices` players; `unit_size` > 0 makes them positional with that
## inverse-distance unit size (m) and `max_distance` cut-off (m).
func _init(voices: int, unit_size: float = 0.0, max_distance: float = 0.0) -> void:
	name = "Voices"
	for _i: int in voices:
		if unit_size > 0.0:
			var spatial: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
			AudioTuning.configure_3d(spatial, unit_size, max_distance)
			_spatial.append(spatial)
			add_child(spatial)
		else:
			var flat: AudioStreamPlayer = AudioStreamPlayer.new()
			_flat.append(flat)
			add_child(flat)


## Play `stream` on the next voice (cutting it off if it still rings).
func play(stream: AudioStream, volume_db: float, pitch: float) -> void:
	if stream == null:
		return
	if not _spatial.is_empty():
		var spatial: AudioStreamPlayer3D = _spatial[_next % _spatial.size()]
		spatial.stream = stream
		spatial.volume_db = volume_db
		spatial.pitch_scale = pitch
		spatial.play()
	elif not _flat.is_empty():
		var flat: AudioStreamPlayer = _flat[_next % _flat.size()]
		flat.stream = stream
		flat.volume_db = volume_db
		flat.pitch_scale = pitch
		flat.play()
	_next += 1


## Voices sounding now (for tests and the debug log).
func playing_count() -> int:
	var n: int = 0
	for flat: AudioStreamPlayer in _flat:
		n += 1 if flat.playing else 0
	for spatial: AudioStreamPlayer3D in _spatial:
		n += 1 if spatial.playing else 0
	return n


## One-shots started since creation.
func started() -> int:
	return _next
