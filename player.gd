extends CharacterBody2D

# Dash config
var dash_speed := 600.0
var dash_duration := 0.3
var double_tap_time := 0.25
var dash_cooldown := 1.0 
var dash_cooldown_timer := 0.0 


# Momentum physics
var acceleration := 2000.0
var friction := 1500.0

# Movement config
var walk_speed := 200.0
var run_speed := 300.0
var jump_velocity := -400.0
var coyote_time := 0.1

# States
var is_dashing := false
var dash_time := 0.0
var last_direction := 0
var double_tap_timer := 0.0
var drop_timer := 0.0
var coyote_timer := 0.0
var was_on_floor := false
var is_anim_locked := false

@onready var anim_sprite = $Sprite

func _physics_process(delta: float) -> void:
	# Ground check and coyote time
	var is_on_floor_now = is_on_floor()
	if is_on_floor_now:
		was_on_floor = true
		coyote_timer = coyote_time
	else:
		if was_on_floor:
			coyote_timer = coyote_time
		was_on_floor = false

	if coyote_timer > 0:
		coyote_timer -= delta
	else:
		coyote_timer = 0

	
	# Get input direction
	var direction := Input.get_axis("Left", "Right")
	
	# Update last direction for movement
	if direction != 0:
		last_direction = sign(direction)
	
	# Double-tap dash detectionn
	if Input.is_action_just_pressed("Left") or Input.is_action_just_pressed("Right"):
		var input_dir = 1 if Input.is_action_just_pressed("Right") else -1
		
		if input_dir == last_direction and double_tap_timer > 0 and (is_on_floor_now or coyote_timer > 0) and dash_cooldown_timer == 0:
			start_dash(input_dir)
		else:
			last_direction = input_dir
			double_tap_timer = double_tap_time
	
	if double_tap_timer > 0:
		double_tap_timer -= delta
	
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
	else:
		dash_cooldown_timer = 0

	
	# Drop through platform
	if drop_timer <= 0 and Input.is_action_pressed("Down") and Input.is_action_just_pressed("ui_accept") and is_on_floor_now:
		drop_timer = 0.2
		set_collision_mask_value(2, false)
	
	if drop_timer > 0:
		drop_timer -= delta
		if drop_timer <= 0:
			set_collision_mask_value(2, true)
	
	# Handle jumping with coyote time
	var velocity = self.velocity
	if Input.is_action_just_pressed("ui_accept"):
		if (is_on_floor_now or coyote_timer > 0) and not Input.is_action_pressed("Down"):
			velocity.y = jump_velocity
			coyote_timer = 0  # Consume coyote time
		
	
	# Apply gravity if not on floor
	if not is_on_floor_now:
		velocity += get_gravity() * delta
	
	# Handle dash movement
	if is_dashing:
		dash_time -= delta
		if dash_time <= 0:
			is_dashing = false
			is_anim_locked = false
			velocity.x = last_direction * walk_speed  # Transition to normal speed
	
	# Calculate target speed based on state
	var target_speed := 0.0
	
	if is_dashing:
		velocity.x = last_direction * dash_speed
	else:
		if Input.is_action_pressed("Run"):
			target_speed = direction * run_speed
		else:
			target_speed = direction * walk_speed
			
		
				
				
			
	
	# Apply acceleration or friction if not dashing
	if not is_dashing:
		if direction != 0:
			# Accelerate toward target speed
			velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		else:
			# Apply friction toward zero when no input
			velocity.x = move_toward(velocity.x, 0, friction * delta)
	
	self.velocity = velocity
	move_and_slide()
	
	if velocity.x != 0:
		anim_sprite.flip_h = velocity.x < 0

	
	# === PLAY ANIMATION BASED ON STATE ===
# === ANIMATION SELECTION ===
	if is_anim_locked:
		return  # Don’t update animation while dash is active

	if not is_on_floor_now:
		if velocity.y < -20:
			anim_sprite.play("jump_up")
		elif abs(velocity.y) <= 20:
			anim_sprite.play("jump_max")
		else:
			anim_sprite.play("fall")

	elif abs(velocity.x) > 10:
		anim_sprite.play("run" if Input.is_action_pressed("Run") else "walk")

	else:
		anim_sprite.play("idle")



func start_dash(direction: int):
	if not is_dashing and (is_on_floor() or coyote_timer > 0) and dash_cooldown_timer == 0:
		is_dashing = true
		dash_time = dash_duration
		dash_cooldown_timer = dash_cooldown
		last_direction = direction
		velocity.y = 0  # Cancel any vertical velocity when dashing
		is_anim_locked = true
		anim_sprite.play("dash")

func play_anim(name: String):
	if anim_sprite.animation != name:
		anim_sprite.play(name)
