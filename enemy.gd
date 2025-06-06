extends RigidBody2D

# Movement properties
@export var patrol_speed := 50.0
@export var chase_speed := 150.0
@export var acceleration := 1000.0
@export var detection_range := 200.0
@export var attack_range := 50.0

# Nodes
@onready var player_detector = $PlayerDetectionArea
@onready var sprite = $Sprite2D
@onready var wall_raycast = $WallRayCast
@onready var floor_raycast = $FloorRayCast
@onready var floor_raycast2 = $FloorRayCast2

# State variables
enum State {PATROL, CHASE, ATTACK}
var current_state = State.PATROL
var patrol_direction = 1
var player_ref = null

func _ready():
	player_detector.body_entered.connect(_on_player_detected)
	player_detector.body_exited.connect(_on_player_lost)
	update_raycast_directions()

func _physics_process(delta):
	# Update raycast directions based on current facing
	#update_raycast_directions()
	
	match current_state:
		State.PATROL:
			patrol(delta)
		State.CHASE:
			chase(delta)
		State.ATTACK:
			attack()

	# Flip sprite based on movement direction
	if linear_velocity.x != 0:
		
		sprite.flip_h = linear_velocity.x < 0

func update_raycast_directions():
	# Point raycasts in current movement direction
	
	wall_raycast.force_raycast_update()
	floor_raycast.force_raycast_update()

func patrol(delta):
	# Check for obstacles
	if wall_raycast.is_colliding() or not floor_raycast.is_colliding():
		patrol_direction = -1
		wall_raycast.scale.x = patrol_direction
		floor_raycast.scale.x = patrol_direction
		$PlayerDetectionArea.scale.x = patrol_direction
	if linear_velocity != Vector2.ZERO:
		$Sprite2D.play("sigbin_walk")
	
	if not floor_raycast.is_colliding() or not floor_raycast2.is_colliding():
		patrol_direction = 1
		wall_raycast.scale.x = patrol_direction
		floor_raycast.scale.x = patrol_direction
		$PlayerDetectionArea.scale.x = patrol_direction
	
	# Only apply force if we're not already moving fast enough
	if abs(linear_velocity.x) < patrol_speed:
		var force = Vector2(patrol_direction * acceleration * mass, 0)
		apply_central_force(force)
	
	# Apply damping to prevent overshooting
	linear_velocity.x = move_toward(linear_velocity.x, patrol_direction * patrol_speed, acceleration * delta)

func chase(delta):
	if player_ref:
		print("Chasing")
		var direction = sign(player_ref.global_position.x - global_position.x)
		var desired_velocity = direction * chase_speed
		var velocity_diff = desired_velocity - linear_velocity.x
		
		# Apply force proportional to how much we need to accelerate
		apply_central_force(Vector2(velocity_diff * mass * 5, 0))
		
		# Check attack range
		if global_position.distance_to(player_ref.global_position) < attack_range:
			current_state = State.ATTACK

func attack():
	# Implement your attack logic here
	print("Attacking player!")
	# After attacking, return to chase state
	current_state = State.CHASE

func _on_player_detected(body):
	if body.name == "CharacterBody2D":  # Change to your player node name
		player_ref = body
		current_state = State.CHASE

func _on_player_lost(body):
	if body == player_ref:
		player_ref = null
		current_state = State.PATROL
