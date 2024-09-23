shader_type spatial;

uniform sampler2D texture_albedo : filter_nearest, repeat_disable;
uniform float rotation;
uniform float uniform_scale;

void vertex()
{
	mat4 billboard_modelview = 
		VIEW_MATRIX *
			mat4(
				INV_VIEW_MATRIX[0],
				INV_VIEW_MATRIX[1],
				INV_VIEW_MATRIX[2],
				MODEL_MATRIX[3]);

	/*
	mat4 y_billboard_modelview = 

		// Convert to viewspace
		INV_CAMERA_MATRIX *

		// Convert to worldspace
		mat4(
			//CAMERA_MATRIX[0],
			vec4(1.0, 0.0, 0.0, 0.0),
			vec4(0.0, 1.0, 0.0, 0.0), // CAMERA_MATRIX[1], 
			vec4(0.0, 0.0, 1.0, 0.0), // CAMERA_MATRIX[2],
			WORLD_MATRIX[3]);
	
	//float rotation = 3.14159/4.0;
	*/

	mat4 rotation_mat = mat4(
		vec4(cos(rotation),  -sin(rotation), 0.0, 0.0),
		vec4(sin(rotation), cos(rotation),   0.0, 0.0),
		vec4(0.0,            0.0,            1.0, 0.0),
		vec4(0.0,            0.0,            0.0, 1.0));

	MODELVIEW_MATRIX = billboard_modelview;
	//VERTEX = (MODELVIEW_MATRIX * rotation_mat * vec4(VERTEX * uniform_scale, 1.0)).xyz;
	//VERTEX.z += 1.0;*/
	
	VERTEX = (rotation_mat * vec4(VERTEX.xyz * uniform_scale, 1)).xyz;
}

void fragment()
{
	vec4 tex_color = texture(texture_albedo, UV);
	EMISSION = tex_color.xyz;
	ALBEDO = vec3(0.0); // tex_color.xyz;
	ALPHA = tex_color.w;
}
