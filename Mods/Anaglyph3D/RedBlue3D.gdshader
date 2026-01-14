shader_type canvas_item;
render_mode blend_premul_alpha,unshaded;
//render_mode unshaded;

uniform sampler2D view_left;
uniform sampler2D view_right;
uniform float luminance_vs_color;

uniform vec4 color_left;
uniform vec4 color_right;

void vertex() {
	// Called for every vertex the material is visible on.
}

float get_luminance(vec4 color) {
	return color.r * 0.2126 + color.g * 0.7152 + color.b * 0.0722;
}

void fragment() {
	// Y = (0.2126 * sRGBtoLin(vR) + 0.7152 * sRGBtoLin(vG) + 0.0722 * sRGBtoLin(vB))

	vec4 tex_left = texture(view_left, UV);
	vec4 tex_right = texture(view_right, UV);

	float left_value = get_luminance(tex_left);
	float right_value = get_luminance(tex_right);
	//float left_value = tex_right.r
	//float right_value = tex_left.g

	//EMISSION = vec3(left_value, 0.0, right_value);
	//ALBEDO = vec3(0.0);
	//ROUGHNESS = 0.0;

	vec3 color_luminance = color_left.rgb * left_value + color_right.rgb * right_value;

	vec3 color_color = tex_left.rgb * color_left.rgb + tex_right.rgb * color_right.rgb;

	float alpha = max(tex_left.a, tex_right.a);

	COLOR = vec4(mix(color_luminance, color_color, luminance_vs_color), alpha);

	//COLOR = vec4(
		//left_value,
		//right_value * 0.75,
		//right_value,
		//max(tex_left.a, tex_right.a));

	//COLOR = vec4(
		//tex_left.r,
		//tex_right.g,
		//tex_right.b,
		//max(tex_left.a, tex_right.a));
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
