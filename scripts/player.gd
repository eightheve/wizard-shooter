extends CharacterBody3D

@onready var head: Node3D = $head
@onready var player_camera: Node3D = $head/player_camera

const MOUSE_SENSITIVITY = 0.125

const WALKING_ACCELERATION = 1.0
const SPRINT_MULTIPLIER = 1.25
const JUMP_VELOCITY = 7.0

const AIR_MOVEMENT_CONTROL_MULTIPLIER = 0.1
const LANDING_CONTROL = 0.75 # The multiplier applied to the character's speed from their max fall height is (1 - this)
const LANDING_RECOVERY_MODIFIER = 0.75 # how quickly the character recovers their acceleration after a fall

const PLAYER_GROUND_FRICTION = 0.15 # The deceleration applied to the character per phys tick
const PLAYER_AIR_FRICTION = AIR_MOVEMENT_CONTROL_MULTIPLIER/4 # Don't mess with this. idk why this works but it does...

# Declaring global variables
var landing_acceleration_multiplier := 1.0
var was_in_air := false
var previous_vertical_velocity := 0.0
var head_bob_timer := 0.0

func _ready(): # Capture mouse in window when focused
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event): # Capture player inputs
	if event is InputEventMouseMotion: # Control camera rotation
		rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
		head.rotate_x(deg_to_rad(-event.relative.y) * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: # Left click handling
		# Eventually I would like this to figure out what kind of weapon is being held, and then call the necessary raycasting / projectile spawning functions.
		var raycast_result = player_camera.shoot_ray(100) # This is junk testing code. shoot_ray takes a max distance as a param
		if raycast_result:
			print(raycast_result.collider)

func _physics_process(delta: float) -> void:
	# Declaring local variables for each phys tick
	#var current_horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var current_forward_speed_multiplier = 1
	var current_friction = PLAYER_GROUND_FRICTION
	var acceleration_multiplier = 1
	
	if not is_on_floor(): # When in air
		velocity += get_gravity() * delta
		acceleration_multiplier = acceleration_multiplier * AIR_MOVEMENT_CONTROL_MULTIPLIER
		current_friction = PLAYER_AIR_FRICTION
		was_in_air = true
		previous_vertical_velocity = velocity.y
	else:
		if was_in_air: # Code to run when touching the ground after being airborne
			var scaled_vertical_velocity = clamp(abs(previous_vertical_velocity), 0, 10) / 10 # All velocity above 10 is ignored, range is normalized to 0-1
			player_camera.set_landing_offset(-scaled_vertical_velocity/5) # Offsets the camera downwards based on vertical velocity
			if previous_vertical_velocity <= -3.5: # Temporarily slows the player (slight punishment for jumping to discourage weird movement)
				var landing_velocity_scale_factor = scaled_vertical_velocity
				landing_acceleration_multiplier = 1 - (LANDING_CONTROL * landing_velocity_scale_factor)
			was_in_air = false
	
	if Input.is_action_pressed("sprint"):
		current_forward_speed_multiplier = SPRINT_MULTIPLIER

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY # This could perhaps be improved. Jumping shouldn't feel so snappy as it should be used sparingly
	
	# Reduces the landing deceleration punishment. The delta could perhaps be replaced with a function instead of a static variable? Could feel better gameplay-wise
	landing_acceleration_multiplier = move_toward(landing_acceleration_multiplier, 1, get_physics_process_delta_time() * LANDING_RECOVERY_MODIFIER)
	# Applies all general acceleration multipliers. So far this is only one, but at some point more may be added.
	acceleration_multiplier = acceleration_multiplier * landing_acceleration_multiplier

	# Since only the X and Z parts of the acceleration vectors are used here, its possible that all of the 3d vectors could be swapped out for 2d vectors, and any Y acceleration (which currently doesnt exist) handled separately.
	var input_dir := Input.get_vector("left", "right", "forward", "backward") # Create 2 dimensional vector based on input
	var local_acceleration_direction := (Vector3(input_dir.x, 0, input_dir.y)).normalized() # Convert to 3d normalized

	# Apply local acceleration multipliers. This is to make sure that sprinting is only applied in the forward direction
	# When stamina is added, will need a check to only drain stamina when the player is ACTUALLY sprinting, not when they are just holding the sprint key and moving backwards/sideways
	var local_acceleration := local_acceleration_direction * Vector3(acceleration_multiplier, 0, acceleration_multiplier * current_forward_speed_multiplier) * WALKING_ACCELERATION
	var global_acceleration := transform.basis * local_acceleration # Convert local accel to global accel
	
	velocity.x = velocity.x + global_acceleration.x # Apply acceleration to velocity
	velocity.z = velocity.z + global_acceleration.z
	
	velocity.x = move_toward(velocity.x, 0, (current_friction * (abs(velocity.x) + 0.5)) ) # Apply friction
	velocity.z = move_toward(velocity.z, 0, (current_friction * (abs(velocity.z) + 0.5)) )

	move_and_slide() # Apply movement
