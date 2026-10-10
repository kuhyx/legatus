class_name BattleSound
extends Node
## Every sound of the live battle, wired once from battle.gd: the general's
## own horse and wind (RiderAudio), the din of the nearest fighting and
## fleeing formations (BattleAudio) and the couriers' hooves (CourierAudio).
## One AudioBank for all, each part with its own RNG off the world seed.

## Offsets so the three RNGs differ for one world seed.
const RIDER_SEED: int = 101
const DIN_SEED: int = 202
## How long before a timed run ends every voice is stopped, s.
const QUIET_BEFORE_QUIT_S: float = 0.25

var bank: AudioBank = null
var rider: RiderAudio = null
var din: BattleAudio = null
var couriers: CourierAudio = null
var _quit_at: float = 0.0
var _elapsed: float = 0.0


func setup(world: BattleWorld, general: General, command: BattleCommand, rng_seed: int) -> void:
	name = "Sound"
	bank = AudioBank.load_dir()
	var sim: BattleSim = world.sim
	rider = RiderAudio.new(general.motion, bank, rng_seed + RIDER_SEED)
	add_child(rider)
	var source: FormationSource = FormationSource.new()
	source.center = sim.get_formation_center
	source.routed = sim.is_formation_routed
	source.engaged = sim.is_formation_engaged
	source.count = sim.get_formation_count
	din = BattleAudio.new()
	din.setup(source, sim.get_formation_strength, world.field.height_at, general.camera())
	din.build(bank, rng_seed + DIN_SEED)
	add_child(din)
	couriers = CourierAudio.new()
	couriers.setup(command.service.couriers, world.field.height_at, general.camera(), bank)
	add_child(couriers)
	_quit_at = BenchScenario.arg("seconds", "0").to_float()
	# Closing the window quits in the same frame too: take the close ourselves.
	get_tree().auto_accept_quit = false


## Quitting within one frame of a voice still playing leaves it unfreed by the
## audio server, and Godot reports leaked instances at exit. A timed run
## (--seconds) goes quiet QUIET_BEFORE_QUIT_S early; a window close goes
## quiet, waits as long, then quits.
func _process(delta: float) -> void:
	_elapsed += delta
	if _quit_at > 0.0 and _elapsed >= _quit_at - QUIET_BEFORE_QUIT_S:
		_go_quiet()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_go_quiet()
		await get_tree().create_timer(QUIET_BEFORE_QUIT_S).timeout
		get_tree().quit()


func _go_quiet() -> void:
	silence(self)
	process_mode = Node.PROCESS_MODE_DISABLED
	print_verbose(
		(
			"audio: own hooves %d, courier hooves %d, din emitters %d"
			% [rider.hooves.started(), couriers.started(), din.active_count()]
		)
	)


## Stop every player under `node` (recursively).
static func silence(node: Node) -> void:
	for child: Node in node.get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stop()
		elif child is AudioStreamPlayer3D:
			(child as AudioStreamPlayer3D).stop()
		silence(child)
