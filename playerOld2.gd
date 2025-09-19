extends CharacterBody3D

@export var speed: float = 14.0
@export var fall_acceleration: float = 75.0
@export var mouse_sensitivity: float = 0.002

var target_velocity = Vector3.ZERO
var boolSpawnFirstTime = false

@onready var cam: Camera3D = $Camera3D
@onready var dig_marker = $Camera3D/digMarker

@onready var voxel_terrain = get_node("/root/world/VoxelTerrain")
@onready var voxel_tool = voxel_terrain.get_voxel_tool()

# Rotation du joueur (yaw) et de la caméra (pitch)
var yaw := 0.0
var pitch := 0.0

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	cam.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	# Contrôle souris pour tourner
	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -1.5, 1.5) # Limite haut/bas pour éviter de faire un 360°

		rotation.y = yaw
		cam.rotation.x = pitch

	# Échap pour libérer la souris
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	if not boolSpawnFirstTime:
		global_position = Vector3(1, 50, 1)
		boolSpawnFirstTime = true
	
	var direction = Vector3.ZERO

	if Input.is_action_pressed("right"):
		direction.x += 1
	if Input.is_action_pressed("left"):
		direction.x -= 1
	if Input.is_action_pressed("down"):
		direction.z += 1
	if Input.is_action_pressed("up"):
		direction.z -= 1
	

	if direction != Vector3.ZERO:
		direction = direction.normalized()
		# Transforme la direction selon où regarde le joueur
		direction = (global_transform.basis * direction).normalized()

	# Ground Velocity
	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	# Gravity
	if not is_on_floor():
		target_velocity.y -= fall_acceleration * delta
	else:
		target_velocity.y = 0.0

	# Apply movement
	velocity = target_velocity
	move_and_slide()

	#######
	### Voxel dig
	#######
	if Input.is_action_just_pressed("dig"):
		voxel_tool.mode = VoxelTool.MODE_REMOVE
		voxel_tool.grow_sphere(dig_marker.global_position, 5.0, 1)
	#	#voxel_tool.do_point($Camera3D/digMarker.global_position)
		rpc("rpc_dig", dig_marker.global_position)
	
	if Input.is_action_just_pressed("make"):
		voxel_tool.mode = VoxelTool.MODE_ADD
		voxel_tool.grow_sphere(dig_marker.global_position, 5.0, 1)
	#	#voxel_tool.do_point($Camera3D/digMarker.global_position)
		rpc("rpc_make", dig_marker.global_position)
	#

@rpc("authority", "call_remote")
func rpc_dig(voxel_pos: Vector3):
	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.grow_sphere(voxel_pos, 1.0, 2)
	
@rpc("authority", "call_remote")
func rpc_make(voxel_pos: Vector3):
	voxel_tool.mode = VoxelTool.MODE_ADD
	voxel_tool.grow_sphere(voxel_pos, 1.0, 2)
