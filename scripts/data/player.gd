extends Resource
class_name Player

# bring Role enum into scope
const Role = preload("res://scripts/data/role.gd").Role

@export var player_id: int = 0
@export var role: int = Role.PLEBIAN
@export var money: int = 0
@export var is_ai: bool = true

# runtime state
var is_consul: bool = false
var is_co_consul: bool = false
var co_consul_count: int = 0
var gold_vote: int = 0
