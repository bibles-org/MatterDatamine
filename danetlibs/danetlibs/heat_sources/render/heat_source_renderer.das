require ecs
require ecs.common
require math
require math.base
require DagorSystem
require DagorMath
require strings
require danetlibs.heat_sources.render.heat_source_common

[es(tag=render)]
def update_heat_sources_pos_es(info : ParallelUpdateFrameDelayed;
                               heat_source__basicScale : float3;
                               heat_source__resultOffset : float3;
                               heat_source__prevCurrVelocityMixCoeff : float;
                               heat_source__inflateCoefMinMax : float2;
                               heat_source__velocityThresholdSq : float;
                               heat_source__shouldInflate : bool;
                               heat_source__inflateSpeed : float;
                               heat_source__temperature : float4;
                               var transform : float3x4&;
                               var heat_source__prevPos : float3&;
                               var heat_source__prevVel : float3&;
                               var heat_source__scale : float3&;
                               var heat_source__inflateCoef : float&)
  var velocityVector = clamp(((transform[3] - heat_source__prevPos) * safeinv(info.dt)), float3(-100.0f), float3(100.0f))
  velocityVector = heat_source__prevCurrVelocityMixCoeff * velocityVector + (1.0 - heat_source__prevCurrVelocityMixCoeff) * heat_source__prevVel
  if heat_source__shouldInflate
    if (length_sq(velocityVector) > heat_source__velocityThresholdSq)
      heat_source__inflateCoef = clamp(heat_source__inflateCoef + heat_source__inflateSpeed * info.dt, heat_source__inflateCoefMinMax.x, heat_source__inflateCoefMinMax.y)
    elif heat_source__temperature.y <= 0.001 // we well shrink the box only after full colldown of heat_source
      heat_source__inflateCoef = clamp(heat_source__inflateCoef - heat_source__inflateSpeed * info.dt, heat_source__inflateCoefMinMax.x, heat_source__inflateCoefMinMax.y)
    heat_source__scale.x = heat_source__basicScale.x
    heat_source__scale.y = heat_source__basicScale.y * heat_source__inflateCoef
    heat_source__scale.z = heat_source__basicScale.z * heat_source__inflateCoef
  else
    heat_source__scale = heat_source__basicScale
  heat_source__prevVel = velocityVector
  heat_source__prevPos = transform[3]
  transform[3] += (velocityVector * info.dt)
  transform[3] += rotate(transform, heat_source__resultOffset)

[es(tag=render, on_appear, track=heat_source__scale)]
def track_heat_sources_size_coeff_es(evt : Event;
                                     heat_source__scale : float3;
                                     heat_source__basicRad : float3;
                                     var heat_source__rad : float3&)
  heat_source__rad = heat_source__basicRad * heat_source__scale

[es(tag=render, on_appear, track=(heat_source__offset, heat_source__radMult))]
def track_heat_sources_offset_rad_mult_es(evt : Event;
                                          heat_source__offset : float3;
                                          heat_source__radMult : float;
                                          heat_source__rad : float3;
                                          heat_source__dirRadOffset : float3;
                                          var heat_source__resultOffset : float3&)
  heat_source__resultOffset = heat_source__offset + heat_source__dirRadOffset * heat_source__rad * heat_source__radMult
