extends CharacterBody3D

@export var speed: float = 14.0
@export var fall_acceleration: float = 75.0
@export var mouse_sensitivity: float = 0.002
@export var jump_velocity: float = 18.0          # ✅ vitesse du saut
@export var dig_interval: float = 0.1            # temps entre chaque dig/make en secondes

@onready var cam: Camera3D = $Camera3D
@onready var dig_marker = $Camera3D/digMarker
@onready var voxel_terrain = get_node("/root/world/VoxelTerrain")
@onready var voxel_tool = voxel_terrain.get_voxel_tool()

var target_velocity = Vector3.ZERO
var boolSpawnFirstTime = false
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

	# Spawn une seule fois
	if not boolSpawnFirstTime:
		global_position = Vector3(1,50,1)
		boolSpawnFirstTime = true

	# --- Mouvement ---
	var direction = Vector3.ZERO
	if Input.is_action_pressed("right"): direction.x += 1
	if Input.is_action_pressed("left"):  direction.x -= 1
	if Input.is_action_pressed("down"):  direction.z += 1
	if Input.is_action_pressed("up"):    direction.z -= 1

	if direction != Vector3.ZERO:
		direction = (global_transform.basis * direction.normalized()).normalized()

	target_velocity.x = direction.x * speed
	target_velocity.z = direction.z * speed

	# ✅ Saut
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			target_velocity.y = jump_velocity
		else:
			target_velocity.y = 0.0
	else:
		target_velocity.y -= fall_acceleration * delta

	velocity = target_velocity
	move_and_slide()

	# --- Dig (retire) ---
	if Input.is_action_pressed("dig"):
		dig_timer -= delta
		if dig_timer <= 0.0:
			var from = cam.global_position + cam.global_transform.basis * Vector3(0,0,-0.5)
			var dir  = (cam.global_transform.basis * Vector3(0,0,-1)).normalized()
			var to   = from + dir * 20.0
			var query = PhysicsRayQueryParameters3D.create(from, to)
			query.exclude = [self]
			var result = get_world_3d().direct_space_state.intersect_ray(query)
			if result:
				var hit_pos = result.get("position", result.get("point", null))
				if hit_pos != null:
					voxel_tool.mode = VoxelTool.MODE_REMOVE
					voxel_tool.grow_sphere(hit_pos, 5.0, 2)
					rpc("rpc_dig", hit_pos)
			dig_timer = dig_interval

	# --- Make (ajoute) ---
	if Input.is_action_pressed("make"):
		make_timer -= delta
		if make_timer <= 0.0:
			voxel_tool.mode = VoxelTool.MODE_ADD
			voxel_tool.grow_sphere(dig_marker.global_position, 5.0, 2)
			rpc("rpc_make", dig_marker.global_position)
			make_timer = dig_interval

@rpc("authority", "call_remote")
func rpc_dig(voxel_pos: Vector3):
	voxel_tool.mode = VoxelTool.MODE_REMOVE
	voxel_tool.grow_sphere(voxel_pos, 5.0, 2)

@rpc("authority", "call_remote")
func rpc_make(voxel_pos: Vector3):
	voxel_tool.mode = VoxelTool.MODE_ADD
	voxel_tool.grow_sphere(voxel_pos, 5.0, 2)
