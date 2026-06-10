extends Node

@export var player_path: NodePath = NodePath("../player")
@export var music_stream: AudioStream = preload("res://asset/1/music/time_for_adventure.mp3")
@export var serene_enter_sound: AudioStream = preload("res://asset/1/sounds/power_up.wav")
@export var normal_volume_db: float = -14.0
@export var serene_volume_db: float = -5.0
@export var normal_pitch_scale: float = 0.82
@export var serene_pitch_scale: float = 1.16
@export var transition_seconds: float = 0.45

var music_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var transition_tween: Tween


func _ready() -> void:
	_configure_music_loop()
	_create_audio_players()
	_connect_player_signals()


func _configure_music_loop() -> void:
	var mp3_stream := music_stream as AudioStreamMP3
	if mp3_stream != null:
		mp3_stream.loop = true


func _create_audio_players() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.stream = music_stream
	music_player.volume_db = normal_volume_db
	music_player.pitch_scale = normal_pitch_scale
	add_child(music_player)
	if music_player.stream != null:
		music_player.play()

	sfx_player = AudioStreamPlayer.new()
	sfx_player.stream = serene_enter_sound
	add_child(sfx_player)


func _connect_player_signals() -> void:
	var player := get_node_or_null(player_path)
	if player == null:
		push_warning("Parkour audio controller could not find player at path: %s" % str(player_path))
		return

	if player.has_signal("serene_state_changed"):
		player.connect("serene_state_changed", Callable(self, "_on_player_serene_state_changed"))


func _on_player_serene_state_changed(active: bool) -> void:
	if active and sfx_player != null and serene_enter_sound != null:
		sfx_player.play()

	if music_player == null:
		return

	if transition_tween != null:
		transition_tween.kill()

	var target_volume := serene_volume_db if active else normal_volume_db
	var target_pitch := serene_pitch_scale if active else normal_pitch_scale
	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	transition_tween.tween_property(music_player, "volume_db", target_volume, transition_seconds)
	transition_tween.tween_property(music_player, "pitch_scale", target_pitch, transition_seconds)
