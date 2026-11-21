// The room's own surfaces (see RoomPanel): walls, floors and counters, painted
// from the room textures by where they are in the world, so the texture runs on
// unbroken from one piece to the next and over a stage's new strip. The floor
// is at y 0 everywhere.
// Walls: wainscot up to lower_height, a trim rail, plaster above, brick on the
// face looking outdoors (outside_dir, per panel), the top in wainscot wood.
// Floors: the floor texture on every face.
// Counters: the counter top on top, cupboard doors down the sides.
// With the soft toon lighting, like everything else.
shader_type spatial;

const int WALL = 0;
const int FLOOR = 1;
const int COUNTER = 2;

uniform int kind = 0;
uniform sampler2D upper_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;  // Plaster; the floor; the counter top.
uniform sampler2D lower_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;  // Wainscot; cupboard doors.
uniform sampler2D trim_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform sampler2D outside_texture : source_color, filter_linear_mipmap, repeat_enable, hint_default_white;
uniform float upper_tile = 2.0;    // Meters one copy of upper_texture covers.
uniform float lower_tile = 1.0;    // Meters across one copy of the wainscot (it spans lower_height tall).
uniform float lower_height = 1.0;  // Top of the wainscot.
uniform float trim_height = 0.12;  // The rail over it.
uniform float trim_aspect = 6.4;   // trim_texture's width over its height.
uniform float outside_tile = 1.2;
uniform float door_aspect = 2.0;   // Cupboard texture's width over its height.
uniform float saturation = 1.0;    // Under 1 calms the colour (the room's warm light already adds plenty).
uniform float brightness = 1.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.9;
instance uniform vec3 outside_dir = vec3(0.0);  // The wall face that looks outdoors (none: zero).
instance uniform float top_y = 1.0;             // A counter's top, for its cupboard doors.

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = world_normal;
	bool flat_face = abs(n.y) > 0.5;
	float along = abs(n.x) > abs(n.z) ? -world_pos.z * sign(n.x) : world_pos.x * sign(n.z);  // Left to right, seen from in front.
	float y = world_pos.y;
	vec3 color;
	if (kind == FLOOR || (kind == COUNTER && flat_face)) {
		color = texture(upper_texture, world_pos.xz / upper_tile).rgb;
	} else if (kind == COUNTER) {
		float tall = max(top_y, 0.1);
		color = texture(lower_texture, vec2(along / (tall * door_aspect), (top_y - y) / tall)).rgb;
	} else if (flat_face) {
		color = texture(lower_texture, world_pos.xz / lower_tile).rgb;
	} else if (dot(n, outside_dir) > 0.5) {
		color = texture(outside_texture, vec2(along, -y) / outside_tile).rgb;
	} else if (y < lower_height) {
		color = texture(lower_texture, vec2(along / lower_tile, (lower_height - y) / lower_height)).rgb;
	} else if (y < lower_height + trim_height) {
		color = texture(trim_texture, vec2(along / (trim_height * trim_aspect), (lower_height + trim_height - y) / trim_height)).rgb;
	} else {
		color = texture(upper_texture, vec2(along, -y) / upper_tile).rgb;
	}
	float grey = dot(color, vec3(0.299, 0.587, 0.114));
	ALBEDO = mix(vec3(grey), color, saturation) * brightness;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;
}

#include "res://assets/shaders/soft_toon_light.gdshaderinc"
