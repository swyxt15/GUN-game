extends CharacterBody2D


const SPEED = 300
const MAX_FALL_VALUE = 200
const BOUNCE_LOSS = 0.75

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@onready var Player = $"../Player"
@onready var Sprite = $"AnimatedSprite2D"
@onready var Explosion = $"explosion"
@onready var tile_map_layer = $"../TileMap/Layer1"
@onready var collision = $"CollisionShape2D"
@onready var collision_explosion = $"CollisionShape2D_explosion"

var angle : float
var facing : int

var will_kill = false

func _ready() -> void:
	velocity = Vector2.from_angle(angle) * SPEED + Player.velocity
	Sprite.flip_h = facing == -1

var can_explode = false

func _physics_process(delta: float) -> void:
	if will_kill:
		kill()
		return
	
	var check_if_offscreen = Player.check_if_offscreen(["left","right","top","bottom"],0,delta,Player.Camera,self)
	if exploded:
		if check_if_offscreen[0] or check_if_offscreen[1] or check_if_offscreen[2] or check_if_offscreen[3]:
			kill()
		return
	
	var collision_info = move_and_collide(velocity * delta)
	if collision_info: # Only when the bomb collided
		velocity = velocity.bounce(collision_info.get_normal()) * BOUNCE_LOSS
	
	if check_if_offscreen[0] or check_if_offscreen[1] or check_if_offscreen[2] or check_if_offscreen[3]:
		kill()
		return
	
	if (Input.is_action_just_released("explode_bomb") and can_explode) or ((floor(abs(velocity.x)) == 0 and floor(velocity.y) <= 2 and collision_info)):
		if not explode():
			kill()
			return
	
	velocity.y += gravity * delta
	velocity.y = min(MAX_FALL_VALUE,velocity.y)
	
	can_explode = true
	
	Sprite.speed_scale = velocity.x / SPEED * facing


func kill():
	get_parent().remove_child(self)
	Player.Bombs.erase(self)

var exploded = false

func explode() -> bool:
	position.x = floor(position.x)
	position.y = floor(position.y)
	var checks = [Vector2(0,0),Vector2(0,-16),Vector2(-16,0),Vector2(0,16),Vector2(16,0)]
	var changes = Vector2(0,0)
	for check in checks:
		var pos = global_position
		pos += check
		var cell = tile_map_layer.local_to_map(tile_map_layer.to_local(pos))
		var data = tile_map_layer.get_cell_tile_data(cell)
		if not (data and data.get_custom_data("can_fix_green_ink")):
			if check == Vector2(0,0):
				return false
			if check.x < 0:
				changes.x = roundi((global_position.x)) % 16
				if changes.x < 0:
					changes.x += 16
				changes.x = (1 - 0.5 - changes.x / 32.0) * -1
			elif check.x > 0:
				changes.x = roundi((global_position.x) * -1) % 16
				if changes.x < 0:
					changes.x += 16
				changes.x = 1 - 0.5 - changes.x / 32.0
			elif check.y < 0:
				changes.y = roundi((global_position.y - 4)) % 16
				if changes.y < 0:
					changes.y += 16
				changes.y = (1 - 0.5 - changes.y / 32.0) * -1
			elif check.y > 0:
				changes.y = roundi((global_position.y - 4) * -1) % 16
				if changes.y < 0:
					changes.y += 16
				changes.y = 1 - 0.5 - changes.y / 32.0
	
	Explosion.get_material().set_shader_parameter("mask_offset",changes)
	print(changes)
	
	collision.disabled = true
	collision_explosion.disabled = false
	collision_explosion.shape.size = Vector2(32,32)
	if changes.x > 0:
		collision_explosion.shape.size.x -= changes.x * 32
	if changes.x < 0:
		collision_explosion.shape.size.x += changes.x * 32
	if changes.y > 0:
		collision_explosion.shape.size.y -= changes.y * 32
	if changes.y < 0:
		collision_explosion.shape.size.y += changes.y * 32

	collision_explosion.position -= changes * 16
	
	Explosion.visible = true
	Sprite.visible = false
	exploded = true
	
	# kills other bombs
	for bomb in Player.Bombs:
		if bomb != self:
			if bomb.exploded:
				bomb.retract()
			else:
				bomb.will_kill = true
			Player.Bombs.erase(bomb)
	
	return true

func retract() -> void:
	Player.change_animation("default",true,Explosion)
	collision_explosion.disabled = true

func _on_explosion_animation_finished() -> void:
	will_kill = true
