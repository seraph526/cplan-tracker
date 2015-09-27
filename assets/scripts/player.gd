extends RigidBody

var body = 0.0;
var pitch = 0.0;

var view_sensitivity = 0.3;
var focus_view_sensv = 0.1;
var walk_speed = 5.0;
var run_multiplier = 1.5;
var move_speed = walk_speed;
var jump_speed = 4.0;

const max_accel = 0.02
const air_accel = 0.1

var fov = 60.0;

const DEFAULT_FOV = 60.0;
const ZOOM_FOV = 25.0;

var zooming = false;

var velocity = Vector3();
var is_moving = false;
var on_floor = false;
var freeze_movement = false;

var attachment_startpos = Vector3();
var bob_angle = Vector3();
var bob_amount = 0.005;

var shooting = false;
var shoot_delay = 0.0;
var gun_clip = 30.0;
var gun_cartridge = gun_clip;
var gun_ammo = 120.0;

var gun_pos = Vector3();

var shadow_enabled = false;

func _input(ie):
	if freeze_movement:
		return;
	
	if ie.type == InputEvent.MOUSE_MOTION:
		var sensitivity = view_sensitivity;
		if zooming:
			sensitivity = focus_view_sensv;
		
		set_body_rot(pitch - ie.relative_y * sensitivity, body - ie.relative_x * sensitivity);
	
	if ie.type == InputEvent.MOUSE_BUTTON:
		if ie.button_index == BUTTON_LEFT:
			shooting = ie.pressed;
		
		if ie.pressed && ie.button_index == BUTTON_RIGHT:
			toggle_zoom(!zooming);
	
	if ie.type == InputEvent.KEY:
		if ie.pressed && Input.is_key_pressed(KEY_R):
			var can_reload = (gun_ammo>0 && gun_clip < gun_cartridge);
			if can_reload:
				if zooming:
					toggle_zoom(false);
				
				var new_clip = gun_clip + gun_ammo;
				if new_clip > gun_cartridge:
					new_clip = gun_cartridge;
				
				gun_ammo -= (new_clip-gun_clip);
				gun_clip = new_clip;
				
				get_node("body/camera/attachment/wpn/AnimationPlayer").play("reload_unsil");
		
		if ie.pressed && Input.is_key_pressed(KEY_F1):
			OS.set_window_fullscreen(!OS.is_window_fullscreen());
		
		if ie.pressed && Input.is_key_pressed(KEY_ESCAPE):
			get_tree().call_deferred("quit");
		
		if ie.pressed && Input.is_key_pressed(KEY_F2):
			var toggle = !get_world().get_environment().is_fx_enabled(Environment.FX_FXAA);
			get_world().get_environment().set_enable_fx(Environment.FX_FXAA, toggle);
			if toggle:
				get_node("/root/main/gui/ingame/chatmessage").add_msg("Anti-aliasing enabled.");
			else:
				get_node("/root/main/gui/ingame/chatmessage").add_msg("Anti-aliasing disabled.");
		
		if ie.pressed && Input.is_key_pressed(KEY_F3):
			var toggle = !get_world().get_environment().is_fx_enabled(Environment.FX_GLOW);
			get_world().get_environment().set_enable_fx(Environment.FX_GLOW, toggle);
			if toggle:
				get_node("/root/main/gui/ingame/chatmessage").add_msg("Glow & bloom enabled.");
			else:
				get_node("/root/main/gui/ingame/chatmessage").add_msg("Glow & bloom disabled.");
		
		if ie.pressed && Input.is_key_pressed(KEY_F4):
			var toggle = !get_world().get_environment().is_fx_enabled(Environment.FX_FOG);
			get_world().get_environment().set_enable_fx(Environment.FX_FOG, toggle);
			if toggle:
				get_node("/root/main/gui/ingame/chatmessage").add_msg("Fog enabled.");
			else:
				get_node("/root/main/gui/ingame/chatmessage").add_msg("Fog disabled.");
		
		if ie.pressed && Input.is_key_pressed(KEY_F5):
			shadow_enabled = !shadow_enabled;
			
			for i in get_tree().get_nodes_in_group("direct_light"):
				i.set("shadow/shadow", shadow_enabled);
			
			if shadow_enabled:
				get_node("/root/main/gui/ingame/chatmessage").add_msg("Shadow enabled.");
			else:
				get_node("/root/main/gui/ingame/chatmessage").add_msg("Shadow disabled.");

func set_body_rot(npitch, nyaw):
	body = fmod(nyaw, 360)
	pitch = max(min(npitch, 90), -90)
	get_node("body").set_rotation(Vector3(0, deg2rad(body), 0))
	get_node("body/camera").set_rotation(Vector3(deg2rad(pitch), 0, 0))

func toggle_zoom(zoom = false):
	if !zoom:
		fov = DEFAULT_FOV;
		zooming = false;
		gun_pos = Vector3();
	else:
		fov = ZOOM_FOV;
		zooming = true;
		gun_pos = Vector3(-0.0353, 0.0075, 0);

func _ready():
	get_node("ray").add_exception(self);
	
	for i in get_tree().get_nodes_in_group("direct_light"):
		i.set("shadow/shadow", false);
	
	set_process_input(true);
	set_process(true);
	set_fixed_process(true);

func _fixed_process(delta):
	if freeze_movement:
		return;
	
	if shooting:
		shoot();
	
	if shoot_delay > 0.0:
		shoot_delay -= delta;
		if shoot_delay < 0.0:
			shoot_delay = 0.0;


func _integrate_forces(state):
	var aim = get_node("body").get_global_transform().basis;
	
	is_moving = false;
	var direction = Vector3();
	
	if !freeze_movement:
		if Input.is_key_pressed(KEY_W):
			direction -= aim[2];
			is_moving = true;
		if Input.is_key_pressed(KEY_S):
			direction += aim[2];
			is_moving = true;
		if Input.is_key_pressed(KEY_A):
			direction -= aim[0];
			is_moving = true;
		if Input.is_key_pressed(KEY_D):
			direction += aim[0];
			is_moving = true;
	
	direction = direction.normalized();
	
	var ray = get_node("ray");
	
	if ray.is_colliding():
		var up = state.get_total_gravity().normalized();
		var normal = ray.get_collision_normal();
		var speed = move_speed;
		var diff = direction * walk_speed - state.get_linear_velocity();
		var vertdiff = aim[1] * diff.dot(aim[1]);
		diff -= vertdiff;
		diff = diff.normalized() * clamp(diff.length(), 0, max_accel / state.get_step());
		diff += vertdiff;
		apply_impulse(Vector3(), diff * get_mass());
		
		if Input.is_key_pressed(KEY_SPACE) && !freeze_movement:
			apply_impulse(Vector3(), Vector3(0,1,0) * jump_speed * get_mass());
	else:
		apply_impulse(Vector3(), Vector3(0,-1,0) * air_accel * get_mass());
	
	state.integrate_forces()

func _process(delta):
	get_node("/root/main/gui/ingame/playerinfo/bg1/ammo").set_text(str(gun_clip,"/",gun_ammo));
	
	if is_moving && !shooting:
		var move_speed = 5.0;
		var trans = Vector3(attachment_startpos.x + bob_amount * -sin(bob_angle.x), attachment_startpos.y + bob_amount * -sin(bob_angle.y), 0);
		var attachment_trans = get_node("body/camera/attachment").get_translation();
		get_node("body/camera/attachment").set_translation(attachment_trans.linear_interpolate(trans, 5*delta));
		bob_angle.x += move_speed*1.5*delta;
		if bob_angle.x >= 2*PI:
			bob_angle.x = 0;
		bob_angle.y += move_speed*1.5*delta;
		if bob_angle.y >= PI:
			bob_angle.y = 0;
	else:
		var move_speed = 5.0;
		var trans = Vector3(0, attachment_startpos.y + bob_amount * 0.5 * -sin(bob_angle.y), 0);
		var attachment_trans = get_node("body/camera/attachment").get_translation();
		get_node("body/camera/attachment").set_translation(attachment_trans.linear_interpolate(trans, 5*delta));
		bob_angle.y += move_speed*0.1*delta;
		if bob_angle.y >= 2*PI:
			bob_angle.y = 0;
		"""
		bob_angle = Vector2(0,0);
		var attachment_trans = get_node("body/camera/attachment").get_translation();
		var trans_x = lerp(attachment_trans.x, attachment_startpos.x, 0.2);
		var trans_y = lerp(attachment_trans.y, attachment_startpos.y, 0.2);
		get_node("body/camera/attachment").set_translation(Vector3(trans_x,trans_y,0));
		"""
	
	get_node("body/camera/attachment/wpn").set_translation(get_node("body/camera/attachment/wpn").get_translation().linear_interpolate(gun_pos, 10*delta));
	
	var cur_fov = get_node("body/camera").get_fov();
	get_node("body/camera").set_perspective(lerp(cur_fov, fov, 10*delta), 0.01, 100.0);

func shoot():
	if shoot_delay > 0.0 || gun_clip <= 0:
		return;
	shoot_delay = 60.0/400.0;
	
	gun_clip -= 1;
	
	var transform = get_viewport().get_camera().get_global_transform();
	var result = get_world().get_direct_space_state().intersect_ray(transform.origin, transform.xform(Vector3(0,0,-1*100)), [self]);
	
	get_node("sfx").play("m4a1_unsil-1");
	get_node("body/camera/attachment/wpn/AnimationPlayer").play("shoot1_unsil");
	
	set_body_rot(pitch + rand_range(0.5, 1.5), body + rand_range(-0.5, 0.5));
	
	if !result.empty():
		var collider = result["collider"];
		#print("Normals: ", rad2deg(result["normal"].x), " , ",rad2deg(result["normal"].y), " , ",rad2deg(result["normal"].z));
		
		if collider != null && collider extends RigidBody:
			if collider.is_in_group("player"):
				print("player ",collider.id," attacked.");
			collider.apply_impulse(result["position"]-collider.get_global_transform().origin, -result["normal"]*4*collider.get_mass());

func _enter_tree():
	get_node("body/camera").make_current();
	freeze_movement = false;
	attachment_startpos = get_node("body/camera/attachment").get_translation();
	
	#OS.set_low_processor_usage_mode(true);
	
	var env = get_world().get_environment();
	env.set_enable_fx(Environment.FX_FXAA, false);
	
	env.set_enable_fx(Environment.FX_GLOW, false);
	env.fx_set_param(Environment.FX_PARAM_GLOW_BLOOM, 0.5);
	
	env.set_enable_fx(Environment.FX_FOG, true);
	
	#return;
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED);

func _exit_tree():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE);
