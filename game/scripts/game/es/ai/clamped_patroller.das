require app
require ecs

[es(tag=server, on_appear)]
def clamped_patroller_range_init(evt : Event;
                                 clamped_patroller__yRangeThreshold : float = 1.0;
                                 transform : float3x4;
                                 var clamped_patroller__yRange : float2&)
  clamped_patroller__yRange = float2(transform[3].y - clamped_patroller__yRangeThreshold,
                                    transform[3].y + clamped_patroller__yRangeThreshold)