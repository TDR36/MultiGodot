extends CharacterBody3D

@export var speed: float = 14.0
@export var fall_acceleration: float = 75.0
@export var mouse_sensitivity: float = 0.002
@export var dig_distance: float = 5.0
@export var dig_interval: float = 0.1  # temps entre chaque dig/make en secondes

var target_velocity = Vector3.ZERO
var boolSpawnFirstTime = false

@onready var cam: Camera3D = $Camera3D
@onready var voxel_terrain = get_node("/root/world/VoxelTerrain")
@onready var voxel_tool = voxel_terrain.get_voxel_tool()

var yaw := 0.0
var pitch := 0.0
var dig_timer: float = 0.0
var make_timer: float = 0.0

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	cam.current = is_multiplayer_authority()
	if is_multiplayer_authority():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		yaw -= event.relative.x * mouse_sensitivity
		pitch -= event.relative.y * mouse_sensitivity
		pitch = clamp(pitch, -1.5, 1.5)

		rotation.y = yaw
		cam.rotation.x = pitch

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return

	if not boolSpawnFirstTime:
		global_position = Vector3(1,50,1)
		boolSpawnFirstTime = true

	# --- Movement ---
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
		direction = (global_transform.basis * direction).normalized()

	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	if not is_on_floor():
		target_velocity.y -= fall_acceleration * delta
	else:
		target_velocity.y = 0.0

	velocity = target_velocity
	move_and_slide()

	# --- Voxel actions en continu ---
	var forward = -cam.global_transform.basis.z.normalized()
	var target_pos = cam.global_position + forward * dig_distance
	target_pos.y = global_position.y  # même hauteur pour éviter de creuser en dessous ou au-dessus

	# Dig
	if Input.is_action_pressed("dig"):
		dig_timer -= delta
		if dig_timer <= 0.0:
			voxel_tool.mode = VoxelTool.MODE_REMOVE
			voxel_tool.grow_sphere(target_pos, 5.0, 2)
			rpc("rpc_dig", target_pos)
			dig_timer = dig_interval

	# Make
	if Input.is_action_pressed("make"):
		make_timer -= delta
		if make_timer <= 0.0:
			voxel_tool.mode = VoxelTool.MODE_ADD
			voxel_tool.grow_sphere(target_pos, 5.0, 2)
			rpc("rpc_make", target_pos)
			make_timer = dig_interval

@rpc("authority", "call_remote")
func rpc_dig(voxel_pos: Vector3):
	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.grow_sphere(voxel_pos, 5.0, 2)

@rpc("authority", "call_remote")
func rpc_make(voxel_pos: Vector3):
	voxel_tool.mode = VoxelTool.MODE_ADD
	voxel_tool.grow_sphere(voxel_pos, 5.0, 2)
