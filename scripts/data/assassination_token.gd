extends Resource
class_name AssassinationToken

# Represents an active assassination token placed on a target player
@export var attacker_id: int = 0  # Player who placed the token
@export var target_id: int = 0    # Player who received the token
@export var rounds_left: int = 3  # How many rounds before it expires (countdown from 3)
@export var placed_this_round: bool = false  # Whether it was placed THIS round (for result screen messaging)
