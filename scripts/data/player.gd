extends Resource
class_name Player

# bring Role enum into scope
const Role = preload("res://scripts/data/role.gd").Role

@export var player_id: int = 0
@export var display_name: String = ""
@export var role: int = Role.PLEBIAN
@export var money: int = 0
@export var is_ai: bool = true

# runtime state
var is_consul: bool = false
var is_co_consul: bool = false
## Number of successful co-consul elections for this player.
## Also drives the Caesar win condition: Caesar wins when his co_consul_count reaches CAESAR_POLICIES_TO_WIN.
var co_consul_count: int = 0
var gold_vote: int = 0
var is_dead: bool = false
var available_assassination_tokens: int = 0  # must stay in [0, 1]
# Plots against Caesar (Greed punishment); separate from placed assassination tokens; max 2 from events
var caesar_plot_marks: int = 0
