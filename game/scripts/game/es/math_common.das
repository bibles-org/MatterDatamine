module math_common shared
require ecs
require math.base


def get_perpendicular_closest_to_axis(norm : float3;
                                      axis : float3)
  let p = perpendicular(norm)
  let p2 = cross(norm, p)
  let axes = fixed_array<float3>(p, -p, p2, -p2)

  var maxDot = dot(axis, axes[0])
  var maxDotIdx = 0
  for i in range(1, 4)
    let dotVal = dot(axis, axes[i])
    if dotVal > maxDot
      maxDot = dotVal
      maxDotIdx = i

  return axes[maxDotIdx]