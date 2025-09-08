require ecs
require net
require app
require ecs.common
require DagorMath
require math.base
require math.random
require DagorRandom
require game.events.events_active_matter



[es(tag=gameClient, on_appear, REQUIRE=(sleeping_trap, firefly_light__maxBrightness))]
def set_firefly_inactive_brighness(evt : Event; var light__brightness : float&)
  light__brightness = 0.0


[es(tag=gameClient, on_appear, REQUIRE_NOT=sleeping_trap)]
def set_firefly_active_flickering(evt : Event;
                                  firefly_ligh__flickerDurationRange : float2;
                                  firefly_light__maxBrightnessRange : float2;
                                  firefly_ligh__countRange : int2;
                                  var firefly_light__maxBrightness : float&;
                                  var firefly_ligh__flickerDuration : float&;
                                  var firefly_ligh__flickerStartsAt : float&;
                                  var firefly_ligh__flickerValues : FloatList)
  firefly_ligh__flickerStartsAt = get_sync_time()
  clear(firefly_ligh__flickerValues)
  firefly_light__maxBrightness = rnd_float(firefly_light__maxBrightnessRange)
  firefly_ligh__flickerDuration = rnd_float(firefly_ligh__flickerDurationRange)
  let count = max(0, rnd_int(firefly_ligh__countRange))
  firefly_ligh__flickerValues |> push(.0)
  for _ in range(count)
    firefly_ligh__flickerValues |> push(saturate((gfrnd() - 0.5) * 4.0)) //thie weird formula is meant to create more extreme values
  firefly_ligh__flickerValues |> push(1.0)


[es(tag=gameClient, REQUIRE_NOT=sleeping_trap)]
def firefly_update_scale_flicker(evt : ParallelUpdateFrameDelayed;
                                 firefly_ligh__flickerStartsAt : float;
                                 firefly_ligh__flickerDuration : float;
                                 firefly_light__maxBrightness : float;
                                 firefly_ligh__flickerValues : FloatList;
                                 var light__brightness : float&)
  let tDelta = evt.curTime - firefly_ligh__flickerStartsAt
  var finalRatio = 1.0
  if tDelta < firefly_ligh__flickerDuration - 0.01
    let count = length(firefly_ligh__flickerValues)
    let deltaFrac = tDelta / firefly_ligh__flickerDuration
    let fromIdx = int(deltaFrac * float(count - 1))
    finalRatio = firefly_ligh__flickerValues[fromIdx]
  light__brightness = finalRatio * firefly_light__maxBrightness


[es(tag=gameClient, parallel_for=4)]
def firefly_update_scale_client(evt : ParallelUpdateFrameDelayed; firefly__scaleViscosity : float;
                                firefly__scale : float; var firefly__clientScale : float&; var transform : float3x4&)
  firefly__clientScale = approach(firefly__clientScale, firefly__scale, evt.dt, firefly__scaleViscosity)
  var tm = transform
  tm[0] = normalize(tm[0])
  tm[1] = normalize(tm[1])
  tm[2] = normalize(tm[2])
  tm = tm * scale_tm(firefly__clientScale)
  transform = tm


[es(tag=gameClient, track=firefly__scale)]
def firefly_overshoot_scale(event : Event; firefly__clientScaleOvershoot, firefly__scale : float; var firefly__clientScale : float&)
  firefly__clientScale = firefly__scale * firefly__clientScaleOvershoot


[es(tag=gameClient, on_appear)]
def firefly_init_spin(act : Event; eid : EntityId; var firefly__spinSpeedOffset : float&)
  firefly__spinSpeedOffset = eid_frnd(eid) * 1000.0


[es(tag=gameClient, after=interp_loc_snapshots_es, before=before_animchar_update_sync, REQUIRE_NOT=(sleeping_trap, deadEntity))]
def firefly_spin_client(act : UpdateStageInfoAct;
                        firefly__spinSpeedOffset : float;
                        firefly__spinSpeedFreq : float;
                        firefly__spinAxisSpeed : float;
                        firefly__spinSpeed : float;
                        firefly__spinCutoff : float;
                        var firefly__spinQuat : float4&;
                        var firefly__spinAxis : float3&;
                        var transform : float3x4)
  //randomly roate axis, rotate tm around axis
  let dSpeed = square(perlin_noise1(act.curTime * firefly__spinSpeedFreq + firefly__spinSpeedOffset) + 1.0 - firefly__spinCutoff)
  let normal1 = get_normal(firefly__spinAxis)
  var normal2 = cross(normal1, firefly__spinAxis)
  var q = quat(normal1, rnd_float(.0, 2.0 * PI))
  normal2 = q * normal2
  q = quat(normal2, firefly__spinAxisSpeed * act.dt)
  firefly__spinAxis = q * firefly__spinAxis
  q = quat(firefly__spinAxis, dSpeed * firefly__spinSpeed * act.dt)
  //localy tm is not reset by snapshots, thus firefly__spinQuat is unnecessary
  let totalQ = is_server() ? q : q * quat(firefly__spinQuat)
  transform[0] = totalQ * transform[0]
  transform[1] = totalQ * transform[1]
  transform[2] = totalQ * transform[2]
  firefly__spinQuat = float4(totalQ)