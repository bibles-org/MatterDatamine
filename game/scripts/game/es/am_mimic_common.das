module am_mimic_common shared
require ecs
require math.base
require DagorMath

//dodecahedron
def generate_directions_5()
  var directions : array<float3>
  let phi = (1.0 + sqrt(5.0)) / 2.0
  let iPhi = 1.0 / phi

  // Group 1: (±1, ±1, ±1) - 8 vertices
  let coords = array<float>(-1.0, 1.0)
  for x_val in coords
    for y_val in coords
      for z_val in coords
        directions |> push(float3(x_val, y_val, z_val))

  // Group 2: (0, ±1/φ, ±φ) and its cyclic permutations - 12 vertices
  for s1 in coords
    for s2 in coords
      // (0, ±iPhi, ±phi)
      directions |> push(float3(0.0, s1 * iPhi, s2 * phi))
      // (±iPhi, ±phi, 0)
      directions |> push(float3(s1 * iPhi, s2 * phi, 0.0))
      // (±phi, 0, ±iPhi)
      directions |> push(float3(s1 * phi, 0.0, s2 * iPhi))

  var normalized_directions : array<float3>
  for d in directions
    normalized_directions |> push(normalize(d))
  return <- directions

//icosahedron
def generate_directions_4() : array<float3>
  var directions : array<float3>
  let phi = (1.0 + sqrt(5.0)) / 2.0 // Golden ratio, approx 1.618
  // (0, ±1, ±phi)
  push(directions, float3(0.0,  1.0,  phi))
  push(directions, float3(0.0,  1.0, -phi))
  push(directions, float3(0.0, -1.0,  phi))
  push(directions, float3(0.0, -1.0, -phi))

  // (±1, ±phi, 0)
  push(directions, float3(1.0,  phi, 0.0))
  push(directions, float3(1.0, -phi, 0.0))
  push(directions, float3(-1.0,  phi, 0.0))
  push(directions, float3(-1.0, -phi, 0.0))

  // (±phi, 0, ±1)
  push(directions, float3(phi, 0.0,  1.0))
  push(directions, float3(phi, 0.0, -1.0))
  push(directions, float3(-phi, 0.0,  1.0))
  push(directions, float3(-phi, 0.0, -1.0))

  for i in range(length(directions))
    directions[i] = normalize(directions[i])
  return <- directions

//cube
def generate_directions_3() : array<float3>
  var directions : array<float3>
  push(directions, float3(1.0,  1.0,  1.0))
  push(directions, float3(1.0,  1.0, -1.0))
  push(directions, float3(1.0, -1.0,  1.0))
  push(directions, float3(1.0, -1.0, -1.0))
  push(directions, float3(-1.0,  1.0,  1.0))
  push(directions, float3(-1.0,  1.0, -1.0))
  push(directions, float3(-1.0, -1.0,  1.0))
  push(directions, float3(-1.0, -1.0, -1.0))

  for i in range(length(directions))
    directions[i] = normalize(directions[i])
  return <- directions

//octahedron
def generate_directions_2() : array<float3>
  var directions : array<float3>
  push(directions, float3(1.0,  0.0,  0.0))  // +X
  push(directions, float3(-1.0,  0.0,  0.0)) // -X
  push(directions, float3(0.0,  1.0,  0.0))  // +Y
  push(directions, float3(0.0, -1.0,  0.0))  // -Y
  push(directions, float3(0.0,  0.0,  1.0))  // +Z
  push(directions, float3(0.0,  0.0, -1.0))  // -Z
  return <- directions

//tetrahedron
def generate_directions_1() : array<float3>
  var directions : array<float3>
  push(directions, float3(1.0,  1.0,  1.0))
  push(directions, float3(1.0, -1.0, -1.0))
  push(directions, float3(-1.0,  1.0, -1.0))
  push(directions, float3(-1.0, -1.0,  1.0))

  for i in range(length(directions))
    directions[i] = normalize(directions[i])
  return <- directions


def generate_directions_N_fibonacci(num_points : int) : array<float3>
  var directions : array<float3>

  if num_points <= 0
    return <- directions
  let golden_angle_rad = PI * (3.0 - sqrt(5.0))

  var y_coord : float
  var radius_at_y : float
  var theta : float
  var x_coord : float
  var z_coord : float

  for i in range(num_points)
    // It ranges from 1.0 (top/north pole) down to -1.0 (bottom/south pole)
    if num_points == 1
      // y_coord = 0.0 will place it on the equator, e.g., (1.0, 0.0, 0.0) after trig.
      // y_coord = 1.0 would place it at the North Pole (0.0, 1.0, 0.0).
      y_coord = 0.0
    else
      // Distribute y_coord evenly from 1.0 down to -1.0
      y_coord = 1.0 - (float(i) / (float(num_points) - 1.0)) * 2.0
    y_coord = clamp(y_coord, .0, 1.0)
    radius_at_y = sqrt(1.0 - y_coord * y_coord)
    theta = golden_angle_rad * float(i)
    x_coord = cos(theta) * radius_at_y
    z_coord = sin(theta) * radius_at_y
    push(directions, float3(x_coord, y_coord, z_coord))

  return <- directions