extends CharacterBody3D

@onready var head: Node3D = $head
@onready var player_camera: Node3D = $head/player_camera

const MOUSE_SENSITIVITY = 0.125

const WALKING_ACCELERATION = 1.0
const SPRINT_MULTIPLIER = 1.25
const JUMP_VELOCITY = 7.0

const AIR_MOVEMENT_CONTROL_MULTIPLIER = 0.1
const LANDING_CONTROL = 0.75 # Higher values make less control.
const LANDING_RECOVERY_MODIFIER = 0.75

const PLAYER_GROUND_FRICTION = 0.15
const PLAYER_AIR_FRICTION = AIR_MOVEMENT_CONTROL_MULTIPLIER/4

var landing_acceleration_multiplier = 1
var was_in_air = false
var previous_vertical_velocity = 0
var head_bob_timer = 0

func _ready(): # Capture mouse in window when focused
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event): # Capture player inputs
	if event is InputEventMouseMotion: # Mouse movement
		rotate_y(deg_to_rad(-event.relative.x * MOUSE_SENSITIVITY))
		head.rotate_x(deg_to_rad(-event.relative.y) * MOUSE_SENSITIVITY)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-89), deg_to_rad(89))
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: # Left click handling
		var raycast_result = player_camera.shoot_ray(100)
		if raycast_result:
			print(raycast_result.collider)

func _physics_process(delta: float) -> void:
	#var current_horizontal_speed = Vector2(velocity.x, velocity.z).length()
	var current_forward_speed_multiplier = 1
	var current_friction = PLAYER_GROUND_FRICTION
	var acceleration_multiplier = 1
	
	if not is_on_floor():
		velocity += get_gravity() * delta
		acceleration_multiplier = acceleration_multiplier * AIR_MOVEMENT_CONTROL_MULTIPLIER
		current_friction = PLAYER_AIR_FRICTION
		was_in_air = true
		previous_vertical_velocity = velocity.y
	else:
		if was_in_air:
			var scaled_vertical_velocity = clamp(abs(previous_vertical_velocity), 0, 10) / 10
			player_camera.set_landing_offset(-scaled_vertical_velocity/5)
			if previous_vertical_velocity <= -3.5:
				var landing_velocity_scale_factor = scaled_vertical_velocity
				landing_acceleration_multiplier = 1 - (LANDING_CONTROL * landing_velocity_scale_factor)
			was_in_air = false
	
	if Input.is_action_pressed("sprint"):
		current_forward_speed_multiplier = SPRINT_MULTIPLIER

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	landing_acceleration_multiplier = move_toward(landing_acceleration_multiplier, 1, get_physics_process_delta_time() * LANDING_RECOVERY_MODIFIER)
	acceleration_multiplier = acceleration_multiplier * landing_acceleration_multiplier
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var local_acceleration_direction := (Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var local_acceleration := local_acceleration_direction * Vector3(acceleration_multiplier, 0, acceleration_multiplier * current_forward_speed_multiplier) * WALKING_ACCELERATION
	var global_acceleration := transform.basis * local_acceleration
	
	velocity.x = velocity.x + global_acceleration.x
	velocity.z = velocity.z + global_acceleration.z
	
	velocity.x = move_toward(velocity.x, 0, (current_friction * (abs(velocity.x) + 0.5)) )
	velocity.z = move_toward(velocity.z, 0, (current_friction * (abs(velocity.z) + 0.5)) )

	move_and_slide()
