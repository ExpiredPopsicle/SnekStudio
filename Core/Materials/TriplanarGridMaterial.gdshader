shader_type spatial;

varying vec3 local_position;
varying vec3 local_normal;

void vertex()
{
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment()
{
	float grid_local_x = fract(local_position.x);
	float grid_local_y = fract(local_position.y);
	float grid_local_z = fract(local_position.z);

	float grid_width = 0.025;
	
	float grid_x_contribution = 0.0;
	float grid_y_contribution = 0.0;
	float grid_z_contribution = 0.0;

	float rounded_x = round(local_position.x);
	float rounded_y = round(local_position.y);
	float rounded_z = round(local_position.z);

	vec3 grid_color = vec3(0.65, 0.65, 0.65);
	vec3 grid_color_darker1 = vec3(0.5, 0.5, 0.5);
	vec3 grid_color_darker2 = vec3(0.25, 0.25, 0.25);

	if(grid_local_x < grid_width || grid_local_x >= 1.0 - grid_width) {
		grid_x_contribution = 1.0;
	}
	if(grid_local_y < grid_width || grid_local_y >= 1.0 - grid_width) {
		grid_y_contribution = 1.0;
	}
	if(grid_local_z < grid_width || grid_local_z >= 1.0 - grid_width) {
		grid_z_contribution = 1.0;
	}

	float total_contribution = 0.0;

	bool facing_x = false;
	bool facing_y = false;
	bool facing_z = false;
	
	if(abs(local_normal.z) > abs(local_normal.y) && abs(local_normal.z) > abs(local_normal.x)) {
		facing_z = true;
	} else if(abs(local_normal.y) > abs(local_normal.x)) {
		facing_y = true;
	} else {
		facing_x = true;
	}

	if(facing_z) {
		total_contribution = max(total_contribution, grid_x_contribution);
		total_contribution = max(total_contribution, grid_y_contribution);
	} else {
		if(rounded_z / 5.0 == round(rounded_z / 5.0) && grid_z_contribution > 0.0) {
			grid_color = min(grid_color, grid_color_darker1);
		}
		if(rounded_z / 10.0 == round(rounded_z / 10.0) && grid_z_contribution > 0.0) {
			grid_color = min(grid_color, grid_color_darker2);
		}
	}
	
	if(facing_x) {
		total_contribution = max(total_contribution, grid_y_contribution);
		total_contribution = max(total_contribution, grid_z_contribution);
	} else {
		if(rounded_x / 5.0 == round(rounded_x / 5.0) && grid_x_contribution > 0.0) {
			grid_color = min(grid_color, grid_color_darker1);
		}
		if(rounded_x / 10.0 == round(rounded_x / 10.0) && grid_x_contribution > 0.0) {
			grid_color = min(grid_color, grid_color_darker2);
		}
	}

	if(facing_y) {
		total_contribution = max(total_contribution, grid_x_contribution);
		total_contribution = max(total_contribution, grid_z_contribution);
	} else {
		if(rounded_y / 5.0 == round(rounded_y / 5.0) && grid_y_contribution > 0.0) {
			grid_color = grid_color_darker1;
		}
		if(rounded_y / 10.0 == round(rounded_y / 10.0) && grid_y_contribution > 0.0) {
			grid_color = grid_color_darker2;
		}
	}

	ALBEDO = mix(vec3(0.75), grid_color, total_contribution);

}
