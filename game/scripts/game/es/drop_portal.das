require ecs
require strings
require DagorMath
require math.base
require DagorSystem
require game.events.events_active_matter


[es(on_appear)]
def drop_portal_init(evt : Event;
                     dportal__openCloseTime : float2;
                     dportal__scales : float2;
                     var dportal__scalingSpd : float&;
                     var dportal__wishScale : float&)
  let rangeScales = dportal__scales.y - dportal__scales.x
  dportal__scalingSpd = rangeScales / dportal__openCloseTime.x
  dportal__wishScale = dportal__scales.y


[es(no_order)]
def portal_scale_change(info : ParallelUpdateFrameDelayed;
                        dportal__wishScale : float;
                        dportal__scalingSpd : float;
                        var dportal__curScale : float&;
                        var transform : float3x4&)
  dportal__curScale = move_to_scalar(dportal__curScale, dportal__wishScale, info.dt, dportal__scalingSpd)
  var tm = scale_tm(dportal__curScale)
  tm[3] = transform[3]
  transform = tm
