shader_type spatial;
varying vec3 wpos;
void vertex() {
    wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    vec2 p = wpos.xz / 5.0;
    float chk = mod(floor(p.x) + floor(p.y), 2.0);
    vec2 g = abs(fract(p - 0.5) - 0.5) / max(fwidth(p), vec2(0.0001));
    float line = 1.0 - clamp(min(g.x, g.y), 0.0, 1.0);
    vec3 base = mix(vec3(0.30, 0.32, 0.34), vec3(0.36, 0.38, 0.40), chk);
    ALBEDO = mix(base, vec3(0.85), line * 0.6);
    ROUGHNESS = 0.95;
}
