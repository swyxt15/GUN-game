extends CharacterBody2D

const MAX_FALL_VALUE = 200
const RANDOM_MODIFIER = PI/16

var has_collided = false
var facing : int

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var color : Color
var velo : int
var aim : bool
var angle : float

var color_to_node = {Color(1,0.5,0) : "orange",Color(1,0,0) : "red",Color(1,0,1) : "pink",Color(0,0.5,1) : "blue"}

@onready var Player = $"../Player"

@onready var Sprite = $"AnimatedSprite2D"
@onready var Collision = $"CollisionShape2D"

@onready var Ink_surface_Sprite = $"ink_surface/AnimatedSprite2D"
@onready var Ink_surface_Collision = $"ink_surface/CollisionShape2D"

@onready var tile_map_layer = $"../TileMap/Layer0"

func _ready() -> void:
	Sprite.set_animation("moving")
	var initial_velo : Vector2
	if aim:
		var cancel_random = 0 if color_to_node[color] == "blue" else 1
		initial_velo = Vector2.from_angle(angle + randf() * RANDOM_MODIFIER * cancel_random) * velo
		facing = cos(angle) / abs(cos(angle))
	else:
		facing = Player.facing
		if facing == -1:
			angle += (PI/2 - angle) * 2
		angle *= -1
		initial_velo = Vector2.from_angle(angle + randf() * RANDOM_MODIFIER) * velo
	velocity = initial_velo + Player.velocity
	
	Ink_surface_Sprite.set_animation("default")
	
	self.modulate = color
	if color_to_node[color] == "red":
		Ink_surface_Collision.disabled = false
		Ink_surface_Collision.shape = RectangleShape2D.new()
		Ink_surface_Collision.shape.size = Vector2(4, 4)
		Ink_surface_Collision.position.y = -2
		$"ink_surface/Kill_Timer".start()
	if color_to_node[color] == "blue":
		self.z_index = -2

func _on_kill_timer_timeout() -> void:
	will_kill = true

var will_kill = false

func _physics_process(delta: float) -> void:
	if will_kill:
		kill()
		return
	if not has_collided:
		if is_on_floor():
			if fix_on_surface("floor"): return
		elif is_on_wall():
			if fix_on_surface("wall"): return
		elif is_on_ceiling():
			if fix_on_surface("ceiling"): return
		else:
			var check_if_offscreen = Player.check_if_offscreen(["left","right","top","bottom"],0,delta,Player.Camera,self)
			if check_if_offscreen[0] or check_if_offscreen[1] or check_if_offscreen[2] or check_if_offscreen[3]:
				kill()
				return
			
			if color_to_node[color] != "blue":
				velocity.y += gravity * delta
				velocity.y = min(MAX_FALL_VALUE,velocity.y)
	move_and_slide()

func fix_on_surface(surface : String) -> bool:
	has_collided = true
	velocity = Vector2(0,0)
	
	# rounds the coordinates to match other pixels
	# and align if the ink is floating
	# if it is too much off
	
	if checks_for_aligning([Vector2(0,0)])[0]:
		kill()
		return true
	
	if surface == "floor":
		position.x = round(position.x/5)*5
		position.y = round(position.y)
		
		var checks = [Vector2(3,3),Vector2(-3,3)]
		var check_result = checks_for_aligning(checks)
		print(check_result)
		if not (check_result[0] or check_result[1]):
			kill()
			return true
		elif not check_result[0]:
			position.x = round(position.x/16)*16
			position.x -= 3
		elif not check_result[1]:
			position.x = round(position.x/16)*16
			position.x += 3
		else:
			check_result = checks_for_aligning([Vector2(-5,-4),Vector2(4,-4),Vector2(-3,-4),Vector2(3,-4)])
			if (check_result[0] and not check_result[2]) or (check_result[1] and not check_result[3]):
				Ink_surface_Sprite.set_animation("fill_between")
			elif check_result[0] and check_result[2]:
				position.x += 1
			elif check_result[1] and check_result[3]:
				position.x -= 1
	elif surface == "ceiling":
		position.x = round(position.x/5)*5
		position.y = round(position.y)
		
		var checks = [Vector2(3,-3),Vector2(-3,-3)]
		var check_result = checks_for_aligning(checks)
		print(check_result)
		if not (check_result[0] or check_result[1]):
			kill()
			return true
		elif not check_result[0]:
			position.x = round(position.x/16)*16
			position.x -= 3
		elif not check_result[1]:
			position.x = round(position.x/16)*16
			position.x += 3
		
		self.rotate(PI)
	elif surface == "wall":
		position.x = round(position.x)
		position.y = round(position.y/5)*5
		
		var checks = [Vector2(3 * facing,3),Vector2(3 * facing,-3)]
		var check_result = checks_for_aligning(checks)
		
		if not (check_result[0] or check_result[1]):
			kill()
			return true
		elif not check_result[0]:
			position.y = round(position.y/16)*16
			position.y -= 1
		elif not check_result[1]:
			position.y = round(position.y/16)*16
			position.y += 9
		else:
			if checks_for_aligning([Vector2(-3 * facing,4)])[0]:
				Ink_surface_Sprite.set_animation("fill_between")
		
		self.rotate(-PI/2 * facing)
	
	
	Collision.disabled = true
	Sprite.visible = false
	Ink_surface_Sprite.visible = true
	Ink_surface_Collision.disabled = false
	
	
	# check if there is already another ink particle at this position
	for particle in Player.Ink_particles:
		if particle != self:
			if round(global_position) == round(particle.global_position):
				if color_to_node[particle.color] == "blue" and color_to_node[color] == "blue":
					kill()
					return true
				else:
					particle.will_kill = true
	
	# enables the surface state
	
	if color_to_node[color] == "red":
		Ink_surface_Collision.shape = RectangleShape2D.new()
		Ink_surface_Collision.shape.size = Vector2(6, 2)
		Ink_surface_Collision.position.y = -1
	
	if color_to_node[color] == "blue":
		if len(Player.blue_particles) == 3:
			Player.blue_particles[0].will_kill = true
			Player.blue_particles.pop_at(0)
		if len(Player.blue_portals) == 3:
			Player.blue_portals.pop_at(0)
		
		Player.blue_portals.append(self)
	
	return false

func kill(particle : Node2D = self) -> void:
	if color_to_node[color] == "blue":
		Player.blue_particles.erase(particle)
		if particle in Player.blue_portals:
			Player.blue_portals.erase(particle)
	
	Player.Ink_particles.erase(particle)
	get_parent().remove_child(particle)
	
	if color_to_node[color] == "red":
		Ink_surface_Collision.shape = RectangleShape2D.new()
		Ink_surface_Collision.shape.size = Vector2(6, 2)
		Ink_surface_Collision.position.y = -1

func checks_for_aligning(checks : Array) -> Array:
	var check_result = []
	for check in checks:
		var pos = global_position + check
		var cell = tile_map_layer.local_to_map(tile_map_layer.to_local(pos))
		var data = tile_map_layer.get_cell_tile_data(cell)
		check_result.append(data and data.get_custom_data("can_fix_ink"))
	return check_result
