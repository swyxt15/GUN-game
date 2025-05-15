extends CharacterBody2D

const MAX_FALL_VALUE = 200
const RANDOM_MODIFIER = 0

var facing : int

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

var velo : int
var angle : float

var Parent : Node2D

@onready var Player = $"../Player"

@onready var Sprite = $"AnimatedSprite2D"
@onready var Collision = $"CollisionShape2D"

func _ready() -> void:
	var initial_velo : Vector2
	if facing == -1:
		angle -= (PI/2 - angle) * 2
	initial_velo = Vector2.from_angle(angle + randf() * RANDOM_MODIFIER) * velo
	velocity = initial_velo + Parent.velocity
	if velocity.y > -50:
		velocity.y = -150
	Player.change_animation("0",true,Sprite)

func kill():
	get_parent().remove_child(self)
	Parent.childs.erase(self)

func _physics_process(delta: float) -> void:
	if is_on_floor() or is_on_wall() or is_on_ceiling():
		kill()
		return
	else:
		var check_if_offscreen = Player.check_if_offscreen(["left","right","top","bottom"],0,delta,Player.Camera,self)
		if check_if_offscreen[0] or check_if_offscreen[1] or check_if_offscreen[2] or check_if_offscreen[3]:
			kill()
			return
		
		velocity.y += gravity * delta
		velocity.y = min(MAX_FALL_VALUE,velocity.y)
	var velo_check = velocity
	velo_check.x = abs(velo_check.x)
	velo_check.y = abs(velo_check.y)
	var result = abs(Vector2(0,0).angle_to_point(velo_check))
	if velocity.y < 0:
		Sprite.flip_v = false
	else:
		Sprite.flip_v = true
	
	Sprite.rotation = 0
	if result > PI/4:
		result = PI/2 - result
		Sprite.flip_h = true
		var modifier = 1
		if facing == -1:
			modifier *= -1
		if velocity.y >= 0:
			modifier *= -1
		Sprite.rotate(PI/2 * modifier)
	else:
		Sprite.flip_h = false
	if result < PI/12 / 2:
		change_frame("0")
	elif result < (PI/6 + PI/12) / 2:
		change_frame("PI_12")
	elif result < (PI/4 + PI/6) / 2:
		change_frame("PI_6")
	else:
		change_frame("PI_4")
	
	if facing == -1:
		Sprite.scale.x = -1
	else:
		Sprite.scale.x = 1
	
	move_and_slide()

func change_frame(animation : String) -> void:
	if Sprite.animation != animation:
		var frame = Sprite.frame
		var progress = Sprite.frame_progress
		Sprite.play(animation)
		Sprite.frame = frame
		Sprite.frame_progress = progress
