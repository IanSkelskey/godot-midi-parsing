extends Node

@export var loop = true
@export var note_materials : Array[Material]

const SPAWN_HEIGHT = 10
const DESCENT_SPEED = 1.5

var delay_time = SPAWN_HEIGHT / float(DESCENT_SPEED)

var notes = []
var notes_on = {}

var midi_player: MidiPlayer
var asp: AudioStreamPlayer

@onready var last_time = 0

# Called when the node enters the scene tree for the first time.
func _ready():
	midi_player = $MidiPlayer
	asp = $AudioStreamPlayer
	# we set the following to true so we can tick the midi player from
	# within our script, this is necessary for accurate syncing with the asp
	midi_player.manual_process = true
	midi_player.loop = false
	midi_player.note.connect(on_note)
	midi_player.play()

	_start_asp_with_delay()

	if loop:
		asp.finished.connect(on_loop)

func _start_asp_with_delay():
	# Delay ASP start using a timer
	print(delay_time)
	var delay_timer := Timer.new()
	delay_timer.wait_time = delay_time  # Delay time until the first note hits the bottom
	delay_timer.one_shot = true
	delay_timer.timeout.connect(_on_timer_timeout)
	add_child(delay_timer)
	delay_timer.start()

func _on_timer_timeout():
	asp.play()

func on_loop():
	# Loop MIDI player
	print("Looping MIDI")
	midi_player.current_time = 0
	midi_player.stop()  # Resets time
	midi_player.play()  # Plays MIDI again
	
	# Restart ASP with the same delay for the loop
	asp.stop()
	_start_asp_with_delay()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):

	# get asp playback time
	var time = asp.get_playback_position() + AudioServer.get_time_since_last_mix()
	# Compensate for output latency.
	time -= AudioServer.get_output_latency()
	
	midi_player.process_delta(delta)

	# spawn notes
	for note in notes_on:
		_spawn_note(note)

	# remove notes when they go off screen
	for note in notes:
		note.position.y -= delta * DESCENT_SPEED
		if note.position.y < 0:
			notes.remove_at(notes.find(note))
			note.queue_free()

func _spawn_note(note):
	# spawn a cube
	var box = MeshInstance3D.new()
	box.mesh = BoxMesh.new()
	box.scale = Vector3(0.1, 0.05, 0.1)
	box.material_override = note_materials[notes_on[note] - 1]
	add_child(box)
	box.owner = get_tree().edited_scene_root
	box.position.y = SPAWN_HEIGHT
	box.position.x = remap(note, 0, 127, -15, 15)
	notes.append(box)

# Called when a "note" type event is played
func on_note(event, track):
	if (event['subtype'] == MIDI_MESSAGE_NOTE_ON): # note on
		notes_on[event['note']] = track
	elif (event['subtype'] == MIDI_MESSAGE_NOTE_OFF): # note off
		notes_on.erase(event['note'])
	#print("[Track: " + str(track) + "] Note on: " + str(event['note']))
