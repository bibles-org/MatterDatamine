require ecs
require strings
require math.base
require math.random
require DagorMath


[es(tag=server, on_appear)]
def transform_scale_on_appear(evt : Event;
                              transform__scaleOnAppearRng : float2;
                              var transform : float3x4&)
  let scale = rnd_float(transform__scaleOnAppearRng)
  transform = transform * scale_tm(scale)
