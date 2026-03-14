extends Node

# main orchestrator for the prototype

# preload data classes so enums/types are available
const Role = preload("res://scripts/data/role.gd").Role
const Player = preload("res://scripts/data/player.gd")
const Policy = preload("res://scripts/data/policy.gd")
const GameState = preload("res://scripts/data/game_state.gd")

@onready var state: GameState = GameState.new()
func role_name(role: int) -> String:
	match role:
		Role.CAESAR:
			return "Caesar"
		Role.PATRICIAN:
			return "Patrician"
		Role.PLEBIAN:
			return "Plebian"
		_:
			return "Unknown"
# Election: consul nominates and players vote
# Policy: consul/co-consul discard, apply influence, run money vote
# Phase flow controlled by state.game_phase

func _ready():
	print("GameManager ready")
	create_players()
	state.all_policies = Policy.example_policies()
	state.game_phase = "init"
	start_round()

func create_players():
	state.players.clear()
	for i in range(6):
		var p = Player.new()
		p.player_id = i
		p.is_ai = true
		state.players.append(p)
	assign_roles()

func assign_roles():
	# simple distribution: 1 Caesar, 2 Patricians, 3 Plebians
	var roles = [Role.CAESAR] + [Role.PATRICIAN, Role.PATRICIAN] + [Role.PLEBIAN, Role.PLEBIAN, Role.PLEBIAN]
	roles.shuffle()
	for i in range(state.players.size()):
		state.players[i].role = roles[i]
		match roles[i]:
			Role.CAESAR:
				state.players[i].money = 8
			Role.PATRICIAN:
				state.players[i].money = 6
			Role.PLEBIAN:
				state.players[i].money = 4

func start_round():
	state.round_number += 1
	print("Starting round %d" % state.round_number)
	distribute_money()
	# make sure consul index is valid
	state.current_consul_index = state.current_consul_index % state.players.size()
	# update runtime flags
	for p in state.players:
		p.is_consul = false
		p.is_co_consul = false
	state.players[state.current_consul_index].is_consul = true
	state.game_phase = "election"
	print_current_consul()

func distribute_money():
	for p in state.players:
		match p.role:
			Role.CAESAR:
				p.money += 8
			Role.PATRICIAN:
				p.money += 6
			Role.PLEBIAN:
				p.money += 4

func print_current_consul():
	var p = state.players[state.current_consul_index]
	print("Consul is player %d (%s)" % [p.player_id, role_name(p.role)])
	print("Current phase: %s" % state.game_phase)

func next_consul():
	state.current_consul_index = (state.current_consul_index + 1) % state.players.size()
	# update runtime flags
	for p in state.players:
		p.is_consul = false
		p.is_co_consul = false
	state.players[state.current_consul_index].is_consul = true
	state.game_phase = "election"
	print_current_consul()

# --- new functionality added below ---

func choose_nominee() -> int:
	var candidates = []
	for i in range(state.players.size()):
		if i != state.current_consul_index:
			candidates.append(i)
	candidates.shuffle()
	return candidates[0]

func conduct_election() -> bool:
	var nominee = choose_nominee()
	print("Consul nominates player %d" % nominee)
	var yes = 0
	var no = 0
	for p in state.players:
		# simple AI vote: random yes/no
		if randi() % 2 == 0:
			yes += 1
		else:
			no += 1
	print("Votes - yes: %d no: %d" % [yes, no])
	if yes > no:
		print("Election passed, player %d is co-consul" % nominee)
		state.current_co_consul_index = nominee
		# update runtime flags
		for p in state.players:
			p.is_co_consul = false
		var co = state.players[nominee]
		co.is_co_consul = true
		co.co_consul_count += 1
		return true
	else:
		print("Election failed")
		return false

func policy_cycle():
	var choices = []
	for i in range(3):
		if state.all_policies.size() > 0:
			choices.append(state.all_policies.pop_back())
	print("Drawn policies:", choices)
	if choices.size() == 0:
		return
	# consul discards random policy
	var idx = randi() % choices.size()
	choices.remove_at(idx)
	print("After consul discard:", choices)
	if choices.size() == 0:
		return
	# co-consul discards random from remaining
	idx = randi() % choices.size()
	choices.remove_at(idx)
	print("Final policy list after co-consul discard:", choices)
	if choices.size() > 0:
		apply_policy(choices[0])

func apply_policy(p: Policy) -> void:
	if p.faction == Role.PATRICIAN:
		state.influence_patrician += 1
	else:
		state.influence_plebian += 1
	print("Applied policy %d (faction %d)" % [p.id, p.faction])
	money_vote(p)

func money_vote(p: Policy) -> void:
	var total_a = 0
	var total_b = 0
	for pl in state.players:
		var spend = pl.money
		pl.money = 0
		if randi() % 2 == 0:
			total_a += spend
		else:
			total_b += spend
	print("Money vote totals A:%d B:%d" % [total_a, total_b])
	if total_a >= total_b:
		apply_benefit(p.option_a_beneficiary, p.option_a_gold_amount)
	else:
		apply_benefit(p.option_b_beneficiary, p.option_b_gold_amount)

func apply_benefit(faction: int, amount: int) -> void:
	for pl in state.players:
		if pl.role == faction and not (faction == Role.PATRICIAN and pl.role == Role.CAESAR):
			pl.money += amount
	print("Applied benefit %d gold to faction %d" % [amount, faction])

func progress():
	match state.game_phase:
		"init":
			start_round()
			state.game_phase = "election"
		"election":
			if conduct_election():
				state.game_phase = "policy"
			else:
				next_consul()
		"policy":
			policy_cycle()
			state.game_phase = "round_end"
		"round_end":
			next_consul()
			start_round()
		_:
			print("Unknown phase: %s" % state.game_phase)
