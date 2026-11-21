class_name ScreenFX
extends CanvasLayer
## Full-screen colour grade over the battlefield (below the HUD): desaturated, slightly warm, hard
## contrast, vignette and film grain. This is what turns the bright "toy" colours into a gritty war look.

const SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float vignette = 0.62;
uniform float grain = 0.05;
uniform float sat = 0.74;
uniform float contrast = 1.10;
uniform vec3 tint = vec3(1.02, 1.0, 0.93);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen_tex, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sat);
	c = (c - 0.5) * contrast + 0.5;
	c *= tint;
	vec2 uv = SCREEN_UV - 0.5;
	float v = smoothstep(0.32, 0.92, length(uv * vec2(1.0, 0.92)));
	c *= 1.0 - v * vignette;
	float g = hash(SCREEN_UV * vec2(1280.0, 720.0) + vec2(fract(TIME * 7.3) * 91.0, fract(TIME * 3.1) * 57.0)) - 0.5;
	c += g * grain;
	COLOR = vec4(max(c, vec3(0.0)), 1.0);
}
"""


func _init(grade: Dictionary = {}) -> void:
	layer = 5
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	# per-map colour grade (data/maps/<id>.json -> biome.grade)
	mat.set_shader_parameter("sat", float(grade.get("sat", 0.74)))
	mat.set_shader_parameter("contrast", float(grade.get("contrast", 1.10)))
	mat.set_shader_parameter("vignette", float(grade.get("vignette", 0.62)))
	mat.set_shader_parameter("grain", float(grade.get("grain", 0.05)))
	var tint_a: Array = grade.get("tint", [1.02, 1.0, 0.93])
	mat.set_shader_parameter("tint", Vector3(float(tint_a[0]), float(tint_a[1]), float(tint_a[2])))
	rect.material = mat
	add_child(rect)
