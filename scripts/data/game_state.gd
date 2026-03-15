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

# Phase result data for UI display
# Election results
var election_nominee_index: int = -1
var election_votes_yes: Array = []  # player IDs that voted yes
var election_votes_no: Array = []   # player IDs that voted no
var election_passed: bool = false
var election_vote_inputs: Array = []  # -1 unset, 0 no, 1 yes
var ineligible_co_consul_indices: Array = []

# Policy results
var policy_drawn_ids: Array = []      # IDs of the 3 drawn policies
var policy_discarded_ids: Array = []   # IDs of the 2 discarded policies
var policy_enacted = null              # the Policy resource that was enacted

# Spending/voting results
var spending_option_a_total: int = 0
var spending_option_b_total: int = 0
var spending_winner: String = ""
var spending_stage: String = "idle"  # idle, input, handoff, resolved
var spending_input_player_index: int = -1
var spending_private_inputs: Array = []  # [{"option": "A"|"B", "amount": int}, ...]
var spending_confirmed_players: Array = []  # bool per player

func _init():
    players = []
    all_policies = []
