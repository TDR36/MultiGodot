extends CharacterBody3D

@export var speed = 14
@export var fall_acceleration = 75
var target_velocity = Vector3.ZERO

var boolSpawnFirstTime = false

@onready var cam = $Camera3D

@onready var voxel_terrain = get_node("/root/world/VoxelTerrain")
@onready var voxel_tool = voxel_terrain.get_voxel_tool()

func _enter_tree() -> void:
	set_multiplayer_authority(name.to_int())

func _ready() -> void:
	cam.current = is_multiplayer_authority()

func _physics_process(delta):
	if is_multiplayer_authority():
		if boolSpawnFirstTime == false:
			global_position = Vector3(1,50,1)
			boolSpawnFirstTime = true
		
		var direction = Vector3.ZERO

		if Input.is_action_pressed("ui_right"):
			direction.x += 1
		if Input.is_action_pressed("ui_left"):
			direction.x -= 1
		if Input.is_action_pressed("ui_down"):
			direction.z += 1
		if Input.is_action_pressed("ui_up"):
			direction.z -= 1

		if direction != Vector3.ZERO:
			direction = direction.normalized()
			# Setting the basis property will affect the rotation of the node.
			# $Pivot.basis = Basis.looking_at(direction)

		# Ground Velocity
		target_velocity.x = direction.x * speed
		target_velocity.z = direction.z * speed

		# Vertical Velocity
		if not is_on_floor(): # If in the air, fall towards the floor. Literally gravity
			target_velocity.y = target_velocity.y - (fall_acceleration * delta)

		# Moving the Character
		velocity = target_velocity
		move_and_slide()
		
		#######
		###Voxel dig
		#######
		
		if Input.is_action_just_pressed("dig"):
			voxel_tool.mode = VoxelTool.MODE_REMOVE
			voxel_tool.do_sphere(global_position,5.0)
