shader_type canvas_item;

uniform float pixel_size : hint_range(1.0, 16.0) = 1.0;
uniform int mix_sampling : hint_range(0, 2) = 0;

varying float theta;
varying vec2 block_size;

vec2 get_neighbor_uv(int index, vec2 uv) {
	switch (index) {
		case 0:
			return vec2(uv.x, uv.y + block_size.y);
		case 1:
			return vec2(uv.x, uv.y - block_size.y);
		case 2:
			return vec2(uv.x + block_size.x, uv.y);
		case 3:
			return vec2(uv.x - block_size.x, uv.y);
		case 4:
			return vec2(uv.x + block_size.x, uv.y + block_size.y);
		case 5:
			return vec2(uv.x + block_size.x, uv.y - block_size.y);
		case 6:
			return vec2(uv.x - block_size.x, uv.y + block_size.y);
		case 7:
			return vec2(uv.x - block_size.x, uv.y - block_size.y);
		default:
			return uv;
	}
}

void vertex() {
	theta = atan(MODEL_MATRIX[0][1], MODEL_MATRIX[0][0]);
	block_size = vec2(pixel_size * TEXTURE_PIXEL_SIZE.x / length(MODEL_MATRIX[0].xy),
				 pixel_size * TEXTURE_PIXEL_SIZE.y / length(MODEL_MATRIX[1].xy));
}

void fragment() {
	mat2 rotation = mat2(vec2(cos(theta), sin(theta)), vec2(-sin(theta), cos(theta)));
	mat2 inverse_rotation = mat2(vec2(cos(theta), -sin(theta)), vec2(sin(theta), cos(theta)));

	vec2 uv = inverse_rotation * (floor(rotation * ((UV - 0.5) / block_size)) + 0.5) * block_size + 0.5;
	vec4 color = texture(TEXTURE, uv);

	if (mix_sampling > 0) {
		vec4 min_color = texture(TEXTURE, get_neighbor_uv(0, uv));
		float min_difference = length(color - min_color);
		for (int i = 1; i < 4 * mix_sampling; i++) {
			vec4 neighbor_color = texture(TEXTURE, get_neighbor_uv(i, uv));
			float difference = length(color - neighbor_color);
			if (difference < min_difference) {
				min_color = neighbor_color;
				min_difference = difference;
			}
		}
		color = min_color;
	}

	float cut_x = max(abs(rotation[0][0] + rotation[0][1]), abs(inverse_rotation[0][0] + inverse_rotation[0][1])) * block_size.x * 0.5;
	float cut_y = max(abs(rotation[1][0] + rotation[1][1]), abs(inverse_rotation[1][0] + inverse_rotation[1][1])) * block_size.y * 0.5;
	if (uv.x < cut_x || uv.x > 1.0 - cut_x || uv.y < cut_y || uv.y > 1.0 - cut_y)
		color.a = 0.0;
	else
		color.a = step(0.5, color.a);

	COLOR = color;
}