extends CharacterBody2D

@export var health = 200
@export var damage = 30

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
var coyote_time := 0.1

# Jump mechanics
var min_jump_velocity := -100.0  # Minimum jump height (when tapped)
var max_jump_velocity := -300.0  # Maximum jump height (when held)
var jump_hold_time := 0.0
var max_jump_hold := 0.2  # Max time button can be held for full height
var is_jump_held := false

# States
var is_dashing := false
var dash_time := 0.0
var last_direction := 0
var double_tap_timer := 0.0
var drop_timer := 0.0
var coyote_timer := 0.0
var was_on_floor := false
var is_anim_locked := false
var mode := ""

# Attack state
var is_attacking := false
var current_attack := ""

# Combo system variables
var current_combo := []
var combo_timer := 0.0
var max_combo_time := 0.5  # Time between attacks to count as combo
var combo_index := 0

# Combo sequences (easily expandable)
var combos := {
	"slash_slash_stab": ["slash", "slash", "stab"],
	"stab_slash": ["stab", "slash"],
	# Add more combos here as needed
}

var weapon = {
	"normal" : "",
	"sword": "sword_",
	"bow": "bow_"
}



@onready var anim_sprite = $Sprite
@onready var slash_collider = $Sprite/SlashCollider
@onready var stab_collider = $Sprite/StabCollider

func _ready() -> void:
	mode = weapon.normal
	slash_collider.monitoring = false
	stab_collider.monitoring = false


func _physics_process(delta: float) -> void:
	# Handle weapon mode switching
	if Input.is_action_just_pressed("Sword Mode") and not mode == weapon.sword:
		mode = weapon.sword
		print("Sword Mode")
	
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
	
	# Double-tap dash detection
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
	
	# Handle jumping with coyote time and variable height
	var velocity = self.velocity
	if Input.is_action_just_pressed("ui_accept") and not is_attacking:
		if (is_on_floor_now or coyote_timer > 0) and not Input.is_action_pressed("Down"):
			# Start jump with minimum velocity
			velocity.y = min_jump_velocity
			coyote_timer = 0
			is_jump_held = true
			jump_hold_time = 0.0
	
		# Increase jump height while button is held
	if is_jump_held:
		jump_hold_time += delta
		if Input.is_action_pressed("ui_accept") and jump_hold_time < max_jump_hold:
			# Apply additional upward force proportional to hold time
			velocity.y = lerp(min_jump_velocity, max_jump_velocity, jump_hold_time/max_jump_hold)
		else:
			# Button released or max hold time reached
			is_jump_held = false
	
	# Apply gravity if not on floor
	if not is_on_floor_now:
		velocity += get_gravity() * delta
	
	# Handle dash movement
	if is_dashing:
		dash_time -= delta
		if dash_time <= 0:
			end_dash()
	
	# Calculate target speed based on state
	var target_speed := 0.0
	
	if is_dashing or is_attacking:  # Prevent movement during attack
		velocity.x = last_direction * (dash_speed if is_dashing else 0)
	else:
		if Input.is_action_pressed("Run"):
			target_speed = direction * run_speed
		else:
			target_speed = direction * walk_speed
	
	# Apply acceleration or friction if not dashing or attacking
	if not is_dashing and not is_attacking:
		if direction != 0:
			velocity.x = move_toward(velocity.x, target_speed, acceleration * delta)
		else:
			velocity.x = move_toward(velocity.x, 0, (friction * 3) * delta)
	
	self.velocity = velocity
	move_and_slide()
	
	if velocity.x != 0 and not is_attacking:  # Don't flip during attack
		#anim_sprite.flip_h = velocity.x < 0
		
		if velocity.x < 0:
			anim_sprite.flip_h = true
			slash_collider.scale = Vector2(-1, 1)
			stab_collider.scale = Vector2(-1, 1)
		else:
			anim_sprite.flip_h = false
			slash_collider.scale = Vector2(1, 1)
			stab_collider.scale = Vector2(1, 1)
	
	
	# Combo timer
	if combo_timer > 0:
		combo_timer -= delta
	else:
		current_combo = []
		combo_index = 0
		
	# Handle attack input
	if mode == weapon.sword and not is_anim_locked:
		if Input.is_action_just_pressed("Primary") and not Input.is_action_pressed("Run"):
			if is_dashing:
				end_dash()
			start_attack("primary")
		elif Input.is_action_just_pressed("Secondary"):
			if is_dashing:
				end_dash()
			start_attack("secondary")
		elif Input.is_action_just_pressed("Tertiary"):
			if is_dashing:
				end_dash()
			start_attack("tertiary")
	
	# Animation handling
	update_animations()

func end_dash():  # NEW FUNCTION
	is_dashing = false
	is_anim_locked = false
	velocity.x = last_direction * walk_speed

func start_attack(input_type: String):
	# Determine which attack to use based on current combo
	var attack_type = get_next_attack_type(input_type)
	current_attack = attack_type
	
	is_attacking = true
	is_anim_locked = true
	
	# Play the appropriate animation
	match attack_type:
		"primary":
			play_anim("slash")
			damage_slash()
			
		"secondary":
			play_anim("parry")
			
			
		"tertiary":
			play_anim("stab")
			damage_stab()
	
	# Wait for animation to finish
	await anim_sprite.animation_finished
	
	# Reset states
	is_attacking = false
	is_anim_locked = false
	update_animations()
	
	# Start combo timeout
	combo_timer = max_combo_time

func damage_slash():
	await get_tree().create_timer(0.2).timeout
	$Sprite/SlashCollider.monitorable = true
	$Sprite/SlashCollider.visible = true
			
	await get_tree().create_timer(0.1).timeout
	$Sprite/SlashCollider.monitorable = false
	$Sprite/SlashCollider.visible = false

func damage_stab():
	await get_tree().create_timer(0.3).timeout
	$Sprite/StabCollider.monitorable = true
	$Sprite/StabCollider.visible = true
			
	await get_tree().create_timer(0.1).timeout
	$Sprite/StabCollider.monitorable = false
	$Sprite/StabCollider.visible = false

func get_next_attack_type(input_type: String) -> String:
	# Record the current input
	var new_combo = current_combo.duplicate()
	new_combo.append(input_type)
	
	# Check if this matches any combo sequence
	for combo_name in combos:
		var combo_sequence = combos[combo_name]
		
		# Check if our current inputs match the start of any combo
		if new_combo.size() <= combo_sequence.size():
			var matches = true
			for i in range(new_combo.size()):
				if new_combo[i] != combo_sequence[i]:
					matches = false
					break
			
			if matches:
				# If we have a partial match, wait for more inputs
				if new_combo.size() < combo_sequence.size():
					current_combo = new_combo
					return input_type  # Use the input type for next attack
				# If we completed a combo, return the first attack of the combo
				else:
					current_combo = []
					return combo_sequence[0]
	
	# No combo match found, use the input type
	current_combo = []
	return input_type

func update_animations():
	if is_anim_locked:
		return
	
	if not is_on_floor():
		if velocity.y < -20:
			play_anim("jump_up")
		elif abs(velocity.y) <= 20:
			play_anim("jump_max")
		else:
			play_anim("fall")
	elif abs(velocity.x) > 10:
		play_anim("run" if Input.is_action_pressed("Run") else "walk")
	else:
		play_anim("idle")

func start_dash(direction: int):
	if not is_dashing and (is_on_floor() or coyote_timer > 0) and dash_cooldown_timer == 0:
		is_dashing = true
		dash_time = dash_duration
		dash_cooldown_timer = dash_cooldown
		last_direction = direction
		velocity.y = 0
		is_anim_locked = true
		play_anim("dash")

func play_anim(name: String):
	if anim_sprite.animation != mode + name:
		anim_sprite.play(mode + name)
