class_name AudioBank
extends RefCounted
## The sound samples, loaded once from assets/audio/ (CC0, fetched by
## scripts/fetch_audio.sh; authors and URLs in assets/audio/sources.tsv).
##
## The files are not in git, so any of them may be missing (CI, offline, a
## fresh clone before install.sh): a missing file is just absent from its list
## and that sound plays nothing. Checked with FileAccess first, so a missing
## file costs no warning. Loaded straight from the file, not through the
## importer, so a sample works before the editor has ever imported it, and
## looping is set here (import settings live in gitignored .import files).

const DEFAULT_DIR: String = "res://assets/audio/"
const HOOVES: PackedStringArray = [
	"hoof_1.wav", "hoof_2.wav", "hoof_3.wav", "hoof_4.wav", "hoof_5.wav"
]
## A nostril snort and a blowing breath (mouth-made; pitched down in play).
const SNORTS: PackedStringArray = ["snort_1.ogg", "blow_1.ogg"]
const CREAKS: PackedStringArray = ["creak_1.ogg", "creak_2.ogg", "creak_3.ogg", "creak_4.ogg"]
const CLASHES: PackedStringArray = [
	"clash_1.ogg",
	"clash_2.ogg",
	"clash_3.ogg",
	"clash_4.ogg",
	"clash_5.ogg",
	"clash_6.ogg",
	"clash_7.ogg",
	"clash_8.ogg",
]
const WIND: String = "wind.wav"
const CROWD: String = "crowd.ogg"

## One-shot variations; empty when none of the files is there.
var hooves: Array[AudioStream] = []
var snorts: Array[AudioStream] = []
var creaks: Array[AudioStream] = []
var clashes: Array[AudioStream] = []
## Loops; null when missing.
var wind: AudioStream = null
var crowd: AudioStream = null


## Every sample found in `dir` (a res:// or absolute directory path).
static func load_dir(dir: String = DEFAULT_DIR) -> AudioBank:
	var bank: AudioBank = AudioBank.new()
	bank.hooves = _load_all(dir, HOOVES)
	bank.snorts = _load_all(dir, SNORTS)
	bank.creaks = _load_all(dir, CREAKS)
	bank.clashes = _load_all(dir, CLASHES)
	bank.wind = load_stream(dir.path_join(WIND), true)
	bank.crowd = load_stream(dir.path_join(CROWD), true)
	return bank


## One .ogg or .wav file, or null if it is not there (no warning).
static func load_stream(path: String, looped: bool) -> AudioStream:
	if not FileAccess.file_exists(path):
		return null
	if path.get_extension() == "ogg":
		var ogg: AudioStreamOggVorbis = AudioStreamOggVorbis.load_from_file(path)
		if ogg != null:
			ogg.loop = looped
		return ogg
	if path.get_extension() == "wav":
		var wav: AudioStreamWAV = AudioStreamWAV.load_from_file(path)
		if wav != null and looped:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		return wav
	return null


## Pick one of `streams` with `rng` (null if the list is empty).
static func pick(streams: Array[AudioStream], rng: RandomNumberGenerator) -> AudioStream:
	if streams.is_empty():
		return null
	return streams[rng.randi_range(0, streams.size() - 1)]


static func _load_all(dir: String, names: PackedStringArray) -> Array[AudioStream]:
	var found: Array[AudioStream] = []
	for file_name: String in names:
		var stream: AudioStream = load_stream(dir.path_join(file_name), false)
		if stream != null:
			found.append(stream)
	return found
