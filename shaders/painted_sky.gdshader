shader_type sky;
// Stylised painted sky: deep blue zenith, pale hazy horizon, soft cartoon clouds.

uniform vec3 zenith : source_color = vec3(0.22, 0.45, 0.82);
uniform vec3 horizon : source_color = vec3(0.72, 0.85, 0.95);
uniform vec3 ground_col : source_color = vec3(0.36, 0.5, 0.36);
uniform vec3 cloud_col : source_color = vec3(1.0, 1.0, 1.0);
uniform vec3 cloud_shade : source_color = vec3(0.66, 0.75, 0.9);
uniform float cloud_cover = 0.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += noise(p) * a;
		p *= 2.03;
		a *= 0.5;
	}
	return v;
}

void sky() {
	float y = EYEDIR.y;
	vec3 col = mix(horizon, zenith, pow(clamp(y, 0.0, 1.0), 0.4));
	if (y > 0.0) {
		// Project onto a cloud plane; clouds stretch towards the horizon.
		vec2 uv = EYEDIR.xz / (y + 0.12) * 1.3 + vec2(TIME * 0.004, 0.0);
		float n = fbm(uv);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.08, n);
		float shade = smoothstep(0.0, 0.25, fbm(uv + vec2(0.06, 0.09)) - n + 0.12);
		vec3 cc = mix(cloud_col, cloud_shade, shade);
		col = mix(col, cc, c * smoothstep(0.0, 0.05, y));
	} else {
		col = mix(horizon, ground_col, clamp(-y * 6.0, 0.0, 1.0));
	}
	COLOR = col;
}
