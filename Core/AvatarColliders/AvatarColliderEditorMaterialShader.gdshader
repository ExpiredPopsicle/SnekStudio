shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, depth_test_disabled;

uniform vec3 color : source_color = vec3(0.5, 0.0, 0.0);
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

varying vec3 viewspace_position;

void vertex() {
	vec4 temp_pos = (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	viewspace_position = temp_pos.xyz / temp_pos.w;
}

void fragment() {

	float depth = texture(DEPTH_TEXTURE, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	float linear_depth = -view.z;
		
	ALBEDO = color;
	if(-VERTEX.z < linear_depth) {
		ALBEDO += color * smoothstep(0.015, 0.0, VERTEX.z + linear_depth) * 5.0;
		ALPHA = 0.9;
	} else {
		ALPHA = 0.35;
	}
	
	ALBEDO += color * clamp(1.0 - NORMAL.z, 0.0, 1.0) * 5.0;
	
}
