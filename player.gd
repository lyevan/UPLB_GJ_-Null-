extends CharacterBody2D

# Dash config
var dash_speed := 600.0
var dash_duration := 0.2
var double_tap_time := 0.25

# Momentum physics
var acceleration := 2000.0
var friction := 1500.0


# Dash state
var is_dashing := false
var dash_time := 0.0

# Double-tap state
var last_direction := 0
var double_tap_timer := 0.0

# Drop-through config
var drop_time := 0.2
var drop_timer := 0.0

# Other movement
var grounded := false
var speed := 200.0

func _physics_process(delta: float) -> void:
	# Ground check
	grounded = $FloorDetector.is_colliding()
	

	# Get input direction
	var direction := Input.get_action_strength("Right") - Input.get_action_strength("Left")

	# Double-tap dash detection
	if Input.is_action_just_pressed("Right") and grounded:
		if last_direction == 1 and double_tap_timer > 0:
			is_dashing = true
			dash_time = dash_duration
			double_tap_timer = 0
		else:
			last_direction = 1
			double_tap_timer = double_tap_time

	elif Input.is_action_just_pressed("Left") and grounded:
		if last_direction == -1 and double_tap_timer > 0:
			is_dashing = true
			dash_time = dash_duration
			double_tap_timer = 0
		else:
			last_direction = -1
			double_tap_timer = double_tap_time


	if double_tap_timer > 0:
		double_tap_timer -= delta

	# Drop through platform
	if drop_timer <= 0 and Input.is_action_pressed("Down") and Input.is_action_just_pressed("ui_accept") and grounded:
		drop_timer = drop_time
		set_collision_mask_value(1, false)

	if drop_timer > 0:
		drop_timer -= delta
		if drop_timer <= 0:
			set_collision_mask_value(1, true)
			

	# Start jump
	var velocity := self.velocity
	if not is_on_floor():
		velocity.y += 1000.0 * delta
	elif Input.is_action_just_pressed("ui_accept") and not Input.is_action_pressed("Down"):
		velocity.y = -400.0

	# Horizontal movement
	var target_speed := 0.0

	if is_dashing:
		velocity.x = last_direction * dash_speed
		dash_time -= delta
		if dash_time <= 0:
			is_dashing = false
			velocity.x = 0  # <<< reset horizontal speed after dash ends

	elif Input.is_action_pressed("Run"):
		target_speed = direction * speed * 1.5
	else:
		target_speed = direction * speed

	# Apply acceleration or friction
	if direction != 0 or is_dashing:
		# Accelerate toward target speed
		velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
	else:
		# Apply friction toward zero when no input
		velocity.x = move_toward(velocity.x, 0, friction * delta)


	self.velocity = velocity
	move_and_slide()
