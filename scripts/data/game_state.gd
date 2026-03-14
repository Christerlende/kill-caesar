extends Resource
class_name GameState

@export var round_number: int = 0
@export var influence_patrician: int = 0
@export var influence_plebian: int = 0

@export var current_consul_index: int = 0
@export var current_co_consul_index: int = -1

var players: Array = []
var all_policies: Array = []
var game_phase: String = "init"

func _init():
    players = []
    all_policies = []
