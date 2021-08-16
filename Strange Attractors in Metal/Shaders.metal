//
//  Shaders.metal
//  Strange Attractors in Metal
//
//  Created by Eduard Dzhumagaliev on 15.08.2021.
//

#include <metal_stdlib>
using namespace metal;

struct Particle {
    float3 position;
    float3 velocity;
};

kernel void firstPass(texture2d<half, access::write> output [[texture(0)]],
                      uint2 id [[thread_position_in_grid]]) {
    output.write(half4(1, 1, 1, 1), id);
}

// Lorenz Attractor Parameters
constant float a = 10.0;
constant float b = 28.0;
constant float c = 2.6666666667;
constant float dt = 0.0001;

kernel void secondPass(texture2d<half, access::read_write> output [[texture(0)]],
                       device Particle *particles [[buffer(0)]],
                       uint id [[thread_position_in_grid]]) {
    Particle particle = particles[id];

    float x = particle.position.x / output.get_width() * 15;
    float y = particle.position.y / output.get_height() * 20;
    float z = particle.position.z / 1000 * 45;

    float dx = (a * (y - x)) * dt;
    float dy = (x * (b - z) - y) * dt;
    float dz = (x * y - c * z) * dt;

    float3 attractorForce = float3(dx, dy, dz) * float3(output.get_width() / 15, output.get_height() / 20, 1000 / 45);
    particle.position += attractorForce;
    particles[id] = particle;

    // projection of the attractor onto the screen
    uint2 pos = uint2(output.get_width() - particle.position.x / 2.4 - 600, output.get_height() - particle.position.z / 0.8 - 600);

    uint2 coord = uint2(id) / uint2(output.get_width(), output.get_height());
    half4 color = output.read(coord);
    color /= half4(1.5, 1.5, 1.2, .1);

    output.write(color, pos);
    output.write(color, pos + uint2( 1, 0));
    output.write(color, pos + uint2( 0, 1));
    output.write(color, pos - uint2( 1, 0));
    output.write(color, pos - uint2( 0, 1));
}
