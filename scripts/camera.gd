extends Camera3D

@onready var player = get_parent().get_parent().get_node(".")

const HEAD_BOB_FREQUENCY = 3.0
const HEAD_BOB_AMPLITUDE = 0.05 # Metres

var head_bob_timer = 0.0
var landing_offset = 0.0

func set_landing_offset(desired_offset: float): # Allows parent player controller to set camera offset
	landing_offset = desired_offset

func shoot_ray(ray_length: float): # Raycasting collision detection. Returns the dict associated with intersect_ray (look at docs) or null if nothing is collided with
	var ray_origin = global_transform.origin
	var ray_end = global_transform.origin + global_transform.basis.z * -ray_length
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_parent().get_parent()]
	
	var space_state = get_world_3d().direct_space_state
	var result = space_state.intersect_ray(query)
	if result:
		return result

func _process(delta: float) -> void: # Handle headbobbing and apply landing offset
	var desired_vertical_offset = 0.0

	var horizontal_speed = Vector2(player.velocity.x, player.velocity.z).length()
	var head_bob_offset = 0.0
	
	if horizontal_speed > 0:
		head_bob_timer += delta * HEAD_BOB_FREQUENCY * horizontal_speed
	else:
		head_bob_timer = 0
		
	head_bob_offset = sin(head_bob_timer) * HEAD_BOB_AMPLITUDE * (horizontal_speed / 5)
	desired_vertical_offset += head_bob_offset + landing_offset
	
	# Makes head position springy to avoid sudden jerkiness when different offsets are applied. Higher delta value is snappier
	position.y = move_toward(position.y, desired_vertical_offset, delta/3)
