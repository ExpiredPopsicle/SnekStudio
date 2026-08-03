shader_type canvas_item;
render_mode blend_premul_alpha,unshaded;

uniform sampler2D view_left;
uniform sampler2D view_right;
uniform float luminance_vs_color;

uniform vec4 color_left;
uniform vec4 color_right;

void vertex() {
}

// FIXME: We might need to do a sRGB-to-linear conversion here.
float get_luminance(vec4 color) {
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722;
}

void fragment() {

	vec4 tex_left = texture(view_left, UV);
	vec4 tex_right = texture(view_right, UV);

	float left_value = get_luminance(tex_left);
	float right_value = get_luminance(tex_right);

	vec3 color_luminance = color_left.rgb * left_value + color_right.rgb * right_value;
	vec3 color_color = tex_left.rgb * color_left.rgb + tex_right.rgb * color_right.rgb;
	float alpha = max(tex_left.a, tex_right.a);

	COLOR = vec4(mix(color_luminance, color_color, luminance_vs_color), alpha);
}
