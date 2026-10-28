extends Node
## Music (with crossfade), pooled SFX and voice playback on separate buses.

const SFX_POOL := 10
const VOICE_SFX := ["goblin_grunt", "goblin_laugh", "king_roar", "goblin_hurt"]

var _streams := {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _voice: AudioStreamPlayer
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _ambience: AudioStreamPlayer
var current_music := ""
var _sfx_cooldown := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_POOL:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_players.append(p)
	_voice = AudioStreamPlayer.new()
	_voice.bus = "Voice"
	add_child(_voice)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_ambience = _make_music_player()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p


func _stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var s: AudioStream = null
	for ext in [".wav", ".ogg"]:
		var path: String = "res://assets/audio/" + sfx_name + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_streams[sfx_name] = s
	return s


func play_sfx(sfx_name: String, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_sfx_cooldown.get(sfx_name, -1000)) < 45:
		return  # avoid stacking identical sounds in the same frame burst
	_sfx_cooldown[sfx_name] = now
	var s := _stream(sfx_name)
	if s == null:
		return
	EventBus.sound_played.emit(sfx_name)
	if sfx_name in VOICE_SFX:
		_voice.stream = s
		_voice.pitch_scale = pitch
		_voice.volume_db = volume_db
		_voice.play()
		return
	for p in _sfx_players:
		if not p.playing:
			p.stream = s
			p.pitch_scale = pitch
			p.volume_db = volume_db
			p.play()
			return
	# All busy: steal the first one.
	_sfx_players[0].stream = s
	_sfx_players[0].play()


func play_music(track: String, fade: float = 1.0) -> void:
	if track == current_music:
		return
	current_music = track
	var s := _stream(track)
	var old := _music_a if _music_a.playing else _music_b
	var new := _music_b if old == _music_a else _music_a
	if s != null:
		new.stream = s
		new.volume_db = -40.0
		new.play()
		create_tween().tween_property(new, "volume_db", 0.0, fade)
	if old.playing:
		var tw := create_tween()
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.tween_callback(old.stop)


func play_ambience(track: String) -> void:
	if track == "":
		_ambience.stop()
		return
	var s := _stream(track)
	if s and _ambience.stream != s:
		_ambience.stream = s
		_ambience.volume_db = -8.0
		_ambience.play()


func stop_music() -> void:
	current_music = ""
	_music_a.stop()
	_music_b.stop()
