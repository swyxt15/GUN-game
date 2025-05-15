extends CharacterBody2D


const SPEED = 5000.0
const JUMP_VELOCITY = -140.0
const JUMP_VELOCITY_INK = -250

const RANGE_SCREEN_BORDER = 8.0
const MAX_FALL_VALUE = 300

const PISTOL_VELOCITY_ORANGE = 250
const PISTOL_VELOCITY_PINK = 400
const OFFSET_PISTOL = Vector2(6,-12)
const OFFSET_CROSSHAIR = Vector2(0,0)
const SNIPER_VELOCITY = 1000
const OFFSET_SNIPER = Vector2(10,-11.5)
const BRUSH_INK_VELOCITY = 125
const OFFSET_BOMB = Vector2(1.5,-11.5)


const MOUSE_SENSITIVITY = 0.5

const BRUSH_DAMAGE = 30
const BRUSH_INK_DAMAGE = 5

const INVINCIBILITY = 1.0
const HEALTH = 100

const DAMAGE_WATER = 20
const DAMAGE_COLLIDE = 40

const VELOCITY_WALL_JUMP = Vector2(100,-150)
const VELOCITY_DASH = 175

const OFFSCREEN_DEATH_RANGE = 5

const KNOCK_BACK_ATTACK = 100

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var facing = 1
var direction_when_jumping = false
var was_on_floor = true
var is_dashing = false

#  0,   0,  320,  180
# left top right bottom

# screen 0 : right -> indx 1 ; left -> indx 2 : {"right": 1, "left": 2}
# screen 1 : left -> indx 0 ; top -> indx 3 : {"left": 0,"top": 3}
# screen 2 : left -> indx 0 {"right": 0}
# etc...

var screens = [{"right": 1, "left": 2},{"left": 0,"bottom":2},{"top": 1,"right": 3},{"left":2, "right":4}, {"left":3,"right":5},{"left":4, "right":6},{"left":5, "right":7},{"left":6, "right":8},{"left":7,"right":9},{"left":8,"right":10},{"left":9,"right":11},{"left":10,"right":12},{"left":11}]
var weapons_per_screen = [[],[],[0],[0],[0,2],[0,1,2],[0,1,2],[4],[3],[0,3,2],[0,4],[0,4,3],[1,2,4]]
var current_screen = 0
var transition = false
var current_border : String
@onready var respawn_pos = position

@onready var FallJump = $"FallJump"
@onready var Idle_timer = $"Idle"

@onready var Tile_Map = $"../TileMap"

@onready var Camera = $"Camera2D"
@onready var Body = $"Body"
@onready var Collision = $"CollisionShape2D"

@onready var Crosshair = $"Crosshair"
@onready var Orange_gun = $"Orange_gun"
@onready var Pink_gun = $"Pink_gun"
@onready var Brush = $"Brush"
@onready var Collision_brush_area = $"Brush_area/CollisionShape2D"
@onready var Sniper = $"Sniper"
@onready var Raycast_sniper = $"RayCastSniper"
@onready var Line_sniper = $"LineSniper"
@onready var Bomb = $"Bomb"

@onready var Hurt_area_collision = $"Hurt_area/CollisionShape2D"

@onready var Raycast_floor = $"RayCast_floor"

@onready var Bouncing_on_wall = $"Bouncing_on_wall"

@onready var Player_explosion = $"../PlayerExplosion"
@onready var Player_explosion_right = $"../PlayerExplosion_right"

@onready var Coyote_time = $"CoyoteTime"

@onready var Progress_bar = $"CanvasLayer/Control/ProgressBar"
@onready var label = $"CanvasLayer/Control/Label"
@onready var Orange_gun_control = $"CanvasLayer/Control/Orange_gun"
@onready var Pink_gun_control = $"CanvasLayer/Control/Pink_gun"
@onready var Brush_control = $"CanvasLayer/Control/Brush"
@onready var Bomb_control = $"CanvasLayer/Control/Bomb"
@onready var Sniper_control = $"CanvasLayer/Control/Sniper"

@onready var weapons_to_control = [Orange_gun_control,Brush_control,Pink_gun_control,Sniper_control,Bomb_control]

var Ink = preload("res://scenes/ink.tscn")
var Bomb_thrown = preload("res://scenes/bomb_thrown.tscn")
var is_touching_ink = {"orange" : 0, "pink" : 0, "blue" : 0, "green" : 0}
var angle : float
var mouse_pos = Vector2(0,0)

var selected_weapon = null
# disabled / available / unobtained
var weapons = ["available","available","available","available","available"]
@onready var weapons_to_node = [Orange_gun,Brush,Pink_gun,Sniper,Bomb]
var weapon_crosshair = [0,2,3,4]

var health = HEALTH

func check_if_offscreen(checks : Array, offscreen_range : float = 0, delta : float = 0, cam : Node2D = Camera, entity : Node2D = self, use_pos : bool = false, pos : Vector2 = Vector2()) -> Array:
	var check_result = []
	var check_pos
	var check_velocity
	
	if not use_pos: # If the script want to use entity for checks
		check_pos = entity.position
		check_velocity = entity.velocity
	else: # If the script want to use position for checks
		check_pos = pos
		check_velocity = Vector2(0,0)
	
	for check in checks:
		if check == "left":
			check_result.append(check_pos.x + check_velocity.x * delta < cam.limit_left + offscreen_range)
		if check == "right":
			check_result.append(check_pos.x - check_velocity.x * delta > cam.limit_right - offscreen_range)
		if check == "top":
			check_result.append(check_pos.y + check_velocity.y * delta < cam.limit_top + offscreen_range)
		if check == "bottom":
			check_result.append(check_pos.y - check_velocity.y * delta > cam.limit_bottom - offscreen_range)
	return check_result

func stop_offscreen(checks : Array, delta : float = 0, cam : Node2D = Camera) -> bool:
	# prevent the player from escaping given screens
	# returns true if player is stopped, false otherwise
	
	if "left" in checks:
		if position.x + velocity.x * delta < cam.limit_left:
			velocity.x = cam.limit_left - position.x
			return true
	if "right" in checks:
		if position.x + velocity.x * delta > cam.limit_right:
			velocity.x = cam.limit_right - position.x
			return true
	if "top" in checks:
		if position.y + velocity.y * delta < cam.limit_top:
			velocity.x = cam.limit_top - position.y
			return true
	if "bottom" in checks:
		if position.y + velocity.y * delta - OFFSCREEN_DEATH_RANGE > cam.limit_bottom:
			kill()
			return true
	return false

func change_room(border:String) -> void:
	if transition:
		return
	
	var Screen = screen_id_to_node(screens[current_screen][border])
	
	# Check if player is not offscreen in the other screen
	var checks = {"left":["top","bottom"],"right":["top","bottom"],"top":["left","right"],"bottom":["left","right"]}
	var check_result = check_if_offscreen(checks[border],0,0,Screen)
	if check_result[0] or check_result[1]:
		stop_offscreen([border])
		return
	
	current_border = border
	if border == "top" or border == "bottom":
		velocity.x /= 7.5
		velocity.y /= 5
	else:
		velocity.y /= 7.5
	
	Body.speed_scale /= 7.5
	transition = true
	Camera.position_smoothing_enabled = true
	current_screen = screens[current_screen][border]
	
	change_camera_limits(Screen)
	
	# kill all ink particles created by the player
	for particle in Ink_particles:
		get_parent().remove_child(particle)
	Ink_particles = []
	
	var crosshair_change_visibility = true
	if not Crosshair.visible:
		crosshair_change_visibility = false
	else:
		Crosshair.visible = false
	
	# Change available weapons
	var disabled_weapons = []
	var enabled_weapons = []
	for i in range(len(weapons)):
		disabled_weapons.append(i)
	for weapon in weapons_per_screen[current_screen]:
		if weapons[weapon] != "unobtained":
			weapons[weapon] = "available"
			disabled_weapons.erase(weapon)
			enabled_weapons.append(weapon)
			if selected_weapon == null:
				select_weapon(weapon)
	for weapon in disabled_weapons:
		if weapons[weapon] != "unobtained":
			weapons[weapon] = "disabled"
			if selected_weapon == weapon:
				select_weapon(null)
	
	if enabled_weapons != []:
		if selected_weapon == null:
			select_weapon(enabled_weapons[0])
	
	await get_tree().create_timer(0.7).timeout
	
	if crosshair_change_visibility and selected_weapon in weapon_crosshair:
		Crosshair.visible = true
	
	Body.speed_scale *= 7.5
	transition = false
	Camera.position_smoothing_enabled = false
	current_border = ""
	
	if border == "top" or border == "bottom":
		velocity.x *= 7.5
		if border == "bottom":
			velocity.y *= 4
	else:
		velocity.y *= 7.5
	
	health = HEALTH
	
	respawn_pos = Raycast_floor.get_collision_point() if Raycast_floor.get_collider() != null else position
	
	for weapon in range(5):
		weapons_to_control[weapon].visible = weapon in weapons_per_screen[current_screen]

func select_weapon(weapon) -> void:
	if selected_weapon != null:
		if selected_weapon in weapon_crosshair:
			Crosshair.visible = false
		weapons_to_node[selected_weapon].visible = false
	
	selected_weapon = weapon
	
	if selected_weapon != null:
		if selected_weapon in weapon_crosshair:
			Crosshair.visible = true
		weapons_to_node[selected_weapon].visible = true

func screen_id_to_node(id : int) -> Node2D:
	return get_node("../Screens/Screen_" + str(id))

func change_camera_limits(cam : Node2D):
	Camera.limit_left = cam.limit_left
	Camera.limit_right = cam.limit_right
	Camera.limit_top = cam.limit_top
	Camera.limit_bottom = cam.limit_bottom

func jump(direction : int) -> void:
	if is_touching_ink["orange"]:
		velocity.y = JUMP_VELOCITY_INK
	else:
		velocity.y = JUMP_VELOCITY
	direction_when_jumping = direction

func apply_gravity(delta:float,slomo:bool) -> void:
	if is_on_floor():
		velocity.y = 0
		was_on_floor = true
		direction_when_jumping = false
		return
	
	if was_on_floor: # for animations
		direction_when_jumping = Input.get_axis("move_left", "move_right")
		was_on_floor = false
	
	var modifier
	if slomo:
		modifier = 7.5**2
	else:
		modifier = 1
	velocity.y += (gravity * delta / 2) / modifier
	velocity.y = min(velocity.y,MAX_FALL_VALUE / modifier)

func _ready():
	Body.flip_h = true
	Idle_timer.timeout.connect(_on_Idle_timer_timeout)
	Body.set_animation("Idle")
	change_camera_limits(screen_id_to_node(current_screen))
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_Idle_timer_timeout() -> void:
	change_animation("Looking",true)
	Idle_timer.start()

var wall_direction : int

var prev_delta = 0
func _physics_process(delta: float) -> void:
	# for debugging
	#if Input.is_action_just_pressed("ui_focus_next"):
		#if Engine.time_scale == 1 and Engine.max_fps == 240:
			#Engine.time_scale = 0.05
			##Engine.max_fps = 10
		#else:
			#Engine.time_scale = 1
			##Engine.max_fps = 240
	
	if len(blue_portals) >= 3:
		blue_portals[0].will_kill = true
		blue_portals.pop_at(0)
	
	Progress_bar.value = health
	label.text = str(health)
	
	if kill_wait:
		velocity *= 0.8
		move_and_slide()
		kill_wait -= 1
		return
	if dead:
		return
	
	var borders = ["left","right","top","bottom"]
	
	# Physics in slomo (when a transition occurs)
	if transition == true:
		if current_border == "right" or current_border == "left":
			apply_gravity(delta,true)
			velocity.x = 0
		else:
			if is_on_floor():
				velocity.x = 0
				change_animation("Idle",false)
		if check_if_offscreen(["left"], RANGE_SCREEN_BORDER, delta)[0]:
			velocity.x = SPEED * delta / 7.5
		if check_if_offscreen(["right"], RANGE_SCREEN_BORDER, delta)[0]:
			velocity.x = -SPEED * delta / 7.5
		move_and_slide()
		return
	
	if not is_on_floor() and was_on_floor and velocity.y >= 0:
		Coyote_time.start()
	
	# Add the gravity.
	apply_gravity(delta,false)
	
	if is_on_floor() and is_dashing:
		is_dashing = false
	
	var direction = Input.get_axis("move_left", "move_right")
	if can_move:
		# Handle jump
		if Input.is_action_just_pressed("jump"):
			if is_on_floor():
				jump(direction)
			else:
				if is_touching_ink["pink"]:
					velocity = VELOCITY_WALL_JUMP
					wall_direction = int(get_wall_normal().x)
					velocity.x *= wall_direction
					Bouncing_on_wall.start()
				else:
					if not Coyote_time.is_stopped():
						jump(direction)
					else:
						FallJump.start()
		elif Input.is_action_pressed("jump"):
			if not FallJump.is_stopped():
				if is_on_floor():
					jump(direction)
					FallJump.stop()
		
		# Adds the horizontal movement
		if direction:
			if Bouncing_on_wall.is_stopped():
				velocity.x = direction * SPEED * delta
			else:
				velocity.x += direction * SPEED * delta * 0.055
				if direction == wall_direction:
					velocity.x = direction * SPEED * delta
			if direction != facing:
				Body.flip_h = direction==1
				var nodes_flipped = [Orange_gun,Brush,Collision_brush_area,Pink_gun,Sniper,Bomb]
				for weapon in nodes_flipped:
					if "flip_h" in weapon:
						weapon.flip_h = direction==-1
					weapon.position.x *= -1
				facing = direction
				Line_sniper.position.x *= -1
			if not is_on_floor():
				direction_when_jumping = true
			
			if not Brush.is_playing() and is_attacking:
				Brush.position.y = -17
				Brush.position.x = 10.5 * facing
				Brush.frame = 0
		else:
			if Bouncing_on_wall.is_stopped():
				velocity.x = move_toward(velocity.x, 0, SPEED)
			else:
				velocity.x /= 60 * delta * 1.1
		
		# Adds the dash
		if Input.is_action_just_pressed("dash"):
			if not is_on_floor() and not is_dashing:
				if is_touching_ink["green"]:
					velocity.y = -VELOCITY_DASH
					if direction:
						velocity.x = VELOCITY_DASH * facing
					Bouncing_on_wall.stop()
					is_dashing = true
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else:
			velocity.x /= 63 * delta
	
	# check if the player is offscreen 
	for border in screens[current_screen].keys():
		borders.erase(border)
		if check_if_offscreen([border],0,delta)[0]:
			change_room(border)
	
	# stops the player if there is no screen where he wants to go
	stop_offscreen(borders,delta)
	
	# animation system
	if is_idle():
		if Idle_timer.is_stopped():
			change_animation("Idle",false)
			Idle_timer.start()
	else:
		if is_on_floor():
			if direction:
				change_animation("Run",true)
			else:
				change_animation("Jump_ground",false)
		else:
			if direction_when_jumping:
				if abs(velocity.y) < 40:
					change_animation("Jump_straight",false)
				elif velocity.y < 0:
					change_animation("Jump_up",false)
				else:
					change_animation("Jump_down",false)
			else:
				change_animation("Jump_ground",false)
		Idle_timer.stop()
	
	angle = Vector2(0,0).angle_to_point(mouse_pos)
	if mouse_pos.distance_to(Vector2(0,0)) > 18:
		mouse_pos = mouse_pos.normalized() * 18
	Crosshairloop()
	Shootloop()
	
	move_and_slide()
	if is_idle():
		# rounds the coordinates to match other pixels
		global_position.x = round(global_position.x)
		global_position.y = round(global_position.y)
	
	prev_delta = delta
	
	if reload_room:
		reload_room -= 1

func is_idle() -> bool:
	return (is_on_floor() and (abs(velocity.x) <= 0.4) or is_on_wall())

func change_animation(animation:String,play:bool, entity : Node2D = Body) -> void:
	if entity.animation != animation:
		entity.set_animation(animation)
	if play:
		entity.play()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var MouseEvent = event.relative
		mouse_pos += MouseEvent * MOUSE_SENSITIVITY
		#if MouseEvent.length() <= 15:
			#mouse_pos += MouseEvent * MOUSE_SENSITIVITY
		#else:
			#mouse_pos = MouseEvent.normalized() * 18
		#mouse_pos = mouse_pos.normalized() * 18
		#print(MouseEvent)
	
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if selected_weapon != null:
				var possible_weapons = available_weapons()
				weapons_to_node[selected_weapon].visible = false
				var select = 1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1
				select_weapon(possible_weapons[(possible_weapons.find(selected_weapon) + select) % len(possible_weapons)])
				weapons_to_node[selected_weapon].visible = true
	
	elif event is InputEventKey and event.pressed and not event.echo:
		var possible_weapons = available_weapons()
		for i in possible_weapons: # tags : Pink Orange Gun              remove at the end of project
			if event.is_action_pressed("weapon_" + str(i)):
				weapons_to_node[selected_weapon].visible = false
				select_weapon(i)
				return


func available_weapons() -> Array:
	var possible_weapons = []
	for weapon in range(len(weapons)):
		if weapons[weapon] == "available":
			possible_weapons.append(weapon)
	return possible_weapons

var raycast_angle

func Crosshairloop():
	var pos = global_position
	var offset = OFFSET_CROSSHAIR
	offset.x *= facing
	pos.y -= 12.5
	Crosshair.global_position = offset + pos + mouse_pos
	
	pos = Crosshair.global_position
	if is_idle():
		Crosshair.global_position = round(Crosshair.global_position)
		Crosshair.global_position.x += 0.5
		Crosshair.global_position.y += 0.5
	
	if selected_weapon == 3:
		var pos_raycast = OFFSET_PISTOL
		pos_raycast.x *= facing
		Raycast_sniper.position = pos_raycast
		Raycast_sniper.target_position = Vector2.from_angle((Raycast_sniper.global_position).angle_to_point(pos)) * 320
		if Raycast_sniper.get_collider() != null:
			Line_sniper.visible = true
			var checks = check_if_offscreen(["left","right","top","bottom"],0,0,Camera,self,true,Raycast_sniper.get_collision_point())
			if not checks[0] and not checks[1] and not checks[2] and not checks[3]:
				raycast_angle = Raycast_sniper.global_position.angle_to_point(Raycast_sniper.get_collision_point())
				Line_sniper.rotation = raycast_angle
				var scale_line = Raycast_sniper.global_position
				scale_line.x += 7 * facing
				Line_sniper.scale = Vector2(scale_line.distance_to(Raycast_sniper.get_collision_point()) / 405 , 1)
				return
	
	Line_sniper.visible = false
	raycast_angle = null
	# previous system
	#
	#var dist = pos.distance_to(mouse_pos)
	#var modifier_pos = (dist - 18) / dist
	#var modifier_mouse = 18 / dist
	#Crosshair.global_position = pos * modifier_pos + mouse_pos * modifier_mouse

var Ink_particles = []

var is_attacking = false
var can_move = true

func Shootloop():
	if not transition and can_move:
		if selected_weapon == 0: # Orange_gun
			if Input.is_action_pressed("shoot"):
				create_ink(OFFSET_PISTOL,Color(1,0.5,0),PISTOL_VELOCITY_ORANGE,angle,true)
		elif selected_weapon == 1: # Brush
			if Input.is_action_just_pressed("shoot"):
				if not is_attacking:
					change_animation("default",true,Brush)
					is_attacking = true
					await get_tree().create_timer(0.28).timeout
					Brush.frame = 0
					Brush.position.y -= 10
					await get_tree().create_timer(0.045).timeout
					is_attacking = false
			elif Input.is_action_just_pressed("attack"):
				if not is_attacking:
					can_move = false
					Brush.frame = 3
					Brush.position.y = -14
					is_attacking = true
					Collision_brush_area.disabled = false
					for i in range(5):
						Brush.position.x += 1 * facing
						await get_tree().create_timer(0.05).timeout
					Collision_brush_area.disabled = true
					for j in range(2):
						for i in range(3-j):
							if Brush.frame != 0:
								Brush.position.x -= 1 * facing
							await get_tree().create_timer(0.05).timeout
						can_move = true
					Brush.frame = 0
					is_attacking = false
					Brush.position.y = -17
		elif selected_weapon == 2: # Pink_gun
			if Input.is_action_pressed("shoot"):
				create_ink(OFFSET_PISTOL,Color(1,0,1),PISTOL_VELOCITY_PINK,angle,true)
		elif selected_weapon == 3: # Sniper
			if Input.is_action_just_pressed("shoot"):
				if raycast_angle != null:
					create_ink(OFFSET_PISTOL,Color(0,0.5,1),SNIPER_VELOCITY,raycast_angle,true)
		elif selected_weapon == 4: # Bomb
			if Input.is_action_just_pressed("shoot"):
				for bomb in Bombs:
					if not bomb.exploded:
						return
				
				var bomb_instance = Bomb_thrown.instantiate()
				var pos = get_global_position()
				pos.y += OFFSET_BOMB.y
				pos.x += OFFSET_BOMB.x * facing
				
				bomb_instance.position = pos
				bomb_instance.angle = angle
				bomb_instance.facing = facing
				get_parent().add_child(bomb_instance)
				Bombs.append(bomb_instance)

var Bombs = []
var blue_particles = []
var blue_portals = []
var teleported = false

func create_ink(offset : Vector2, color : Color, velo : int, ink_angle : float, aim : bool) -> void:
	var ink_instance = Ink.instantiate()
	
	var pos = get_global_position()
	pos.y += offset.y
	pos.x += offset.x * facing
	
	ink_instance.position = pos
	ink_instance.color = color
	ink_instance.velo = velo
	ink_instance.angle = ink_angle
	ink_instance.aim = aim
	get_parent().add_child(ink_instance)
	
	Ink_particles.append(ink_instance)
	
	if color == Color(0,0.5,1): # blue
		blue_particles.append(ink_instance)

func _on_brush_frame_changed() -> void:
	if Brush.frame == 1 or Brush.frame == 7:
		Brush.position.y += 1
	elif Brush.frame == 2 or Brush.frame == 3 or Brush.frame == 5 or Brush.frame == 6:
		Brush.position.y += 2

	if Brush.frame == 1 or Brush.frame == 2 or Brush.frame == 5 or Brush.frame == 6:
		var offset = {1:[Vector2(13.5,-18.5),PI/6],2:[Vector2(15.5,-14.5),PI/12],3:[Vector2(16.5,-11.5),0],5:[Vector2(15.5,-8.5),-PI/12],6:[Vector2(13.5,-4.5),-PI/6]}
		create_ink(offset[Brush.frame][0],Color(1,0,0),BRUSH_INK_VELOCITY,offset[Brush.frame][1],false)

func cant_move(time : float) -> void:
	can_move = false
	await get_tree().create_timer(time).timeout
	can_move = true

func _on_hurt_area_body_entered(body: Node2D) -> void:
	if transition:
		return
	
	cant_move(0.25)
	
	if "Parent" in body: # water
		health -= DAMAGE_WATER
		velocity.x = KNOCK_BACK_ATTACK / 1.5 * body.facing
		velocity.y = -abs(velocity.x)
	elif "player_detected" in body: # slime
		velocity.x = (position.x - body.position.x)/abs(position.x - body.position.x) * KNOCK_BACK_ATTACK
		velocity.y = -abs(velocity.x)
		health -= DAMAGE_COLLIDE
	
	move_and_slide()
	
	flicker()
	if health <= 0:
		health = 0
		kill()
	
	Hurt_area_collision.set_deferred("disabled", true)
	await get_tree().create_timer(INVINCIBILITY).timeout
	Hurt_area_collision.set_deferred("disabled", false)

func flicker() -> void:
	for node in [Body,Orange_gun,Brush,Pink_gun,Sniper,Bomb]:
		var tween = create_tween()
		tween.tween_property(node,"material:shader_parameter/amount", 1.0, 0.0)
		tween.tween_property(node,"material:shader_parameter/amount", 0.0, 0.2)

var reload_room = 0
var dead = false
var kill_wait = 0

func kill():
	if dead:
		return
	
	dead = true
	
	change_animation("Jump_down",false)
	Collision.set_deferred("disabled", true)
	await get_tree().create_timer(0.001).timeout
	velocity = Vector2(-500 * facing,-500)
	kill_wait = 15
	while kill_wait > 0:
		await get_tree().create_timer(1/60.0).timeout
	
	var pos = global_position
	pos.y -= 12.5
	
	var gpu_particle
	if facing == -1:
		gpu_particle = Player_explosion
	else:
		gpu_particle = Player_explosion_right
	
	gpu_particle.position = pos
	await get_tree().create_timer(0.001).timeout
	
	gpu_particle.restart()
	await get_tree().create_timer(0.03).timeout
	
	var hidden_nodes = [Body,Orange_gun,Brush,Pink_gun,Sniper,Bomb,Crosshair]
	for node in hidden_nodes:
		node.visible = false
	
	await get_tree().create_timer(1).timeout
	
	health = HEALTH
	reload_room = 2
	position = respawn_pos
	
	var particles = Array(Ink_particles) + Array(Bombs)
	for particle in particles:
		get_parent().remove_child(particle)
	Ink_particles = []
	Bombs = []
	
	Collision.disabled = false
	Body.visible = true
	if selected_weapon != null:
		weapons_to_node[selected_weapon].visible = true
	if selected_weapon in weapon_crosshair:
		Crosshair.visible = true
	dead = false
	change_animation("Idle",false)

func _on_green_ink_area_body_entered(body: Node2D) -> void:
	if "exploded" in body:
		if body.exploded == true:
			is_touching_ink["green"] += 1

func _on_green_ink_area_body_exited(body: Node2D) -> void:
	if "exploded" in body:
		if body.exploded == true:
			is_touching_ink["green"] -= 1
