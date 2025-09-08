require ecs
require math
require math.base
require math.easing
require DagorMath
require DagorSystem
require game.es.tweening_common
require game.events.events_active_matter


[es(no_order)]
def tweening_sphere_zone_radius_smooth(evt : ParallelUpdateFrameDelayed;
                                       eid : EntityId;
                                       tweening_sphere_zone_radius_smooth__fromRadius : float;
                                       tweening_sphere_zone_radius_smooth__toRadius : float;
                                       tweening_sphere_zone_radius_smooth__time : float;
                                       var tweening_sphere_zone_radius_smooth__timer : float&;
                                       var sphere_zone__radius : float&)
  tweening_sphere_zone_radius_smooth__timer += evt.dt
  if tweening_sphere_zone_radius_smooth__timer >= tweening_sphere_zone_radius_smooth__time
    sphere_zone__radius = tweening_sphere_zone_radius_smooth__toRadius
    removeSubTemplate(eid, "tweening_sphere_zone_radius_smooth")
  else
    let t = safediv(tweening_sphere_zone_radius_smooth__timer, tweening_sphere_zone_radius_smooth__time)
    let smoothT = inOutBezier(t)
    sphere_zone__radius = lerp(tweening_sphere_zone_radius_smooth__fromRadius,
                               tweening_sphere_zone_radius_smooth__toRadius,
                               smoothT)


def set_transform_scale(var transform : float3x4;
                        scale : float3)
  let prevScale = float3(length(transform[0]), length(transform[1]), length(transform[2]))
  transform = transform * scale_tm(scale * safeinv(prevScale))


[es(no_order)]
def tweening_transform_scale_smooth(evt : ParallelUpdateFrameDelayed;
                                    eid : EntityId;
                                    tweening_transform_scale_smooth__from : float3;
                                    tweening_transform_scale_smooth__to : float3;
                                    tweening_transform_scale_smooth__time : float;
                                    var tweening_transform_scale_smooth__timer : float&;
                                    var transform : float3x4)
  tweening_transform_scale_smooth__timer += evt.dt
  if tweening_transform_scale_smooth__timer >= tweening_transform_scale_smooth__time
    set_transform_scale(transform, tweening_transform_scale_smooth__to)
    removeSubTemplate(eid, "tweening_transform_scale_smooth")
  else
    let t = safediv(tweening_transform_scale_smooth__timer, tweening_transform_scale_smooth__time)
    let smoothT = inOutBezier(t)
    let newScale = lerp(tweening_transform_scale_smooth__from,
                        tweening_transform_scale_smooth__to,
                        float3(smoothT))
    set_transform_scale(transform, newScale)


[es(on_appear)]
def tweening_transform_pos_init(evt : Event;
                                transform : float3x4;
                                var tweening_transform_pos__from : float3&)
  tweening_transform_pos__from = transform[3]


[es(no_order)]
def tweening_transform_pos(evt : ParallelUpdateFrameDelayed;
                           eid : EntityId;
                           tweening_transform_pos__from : float3;
                           tweening_transform_pos__to : float3;
                           tweening_transform_pos__time : float;
                           tweening_transform_pos__lerpPow : float;
                           var tweening_transform_pos__timer : float&;
                           var transform : float3x4)
  tweening_transform_pos__timer += evt.dt
  if tweening_transform_pos__timer >= tweening_transform_pos__time
    transform[3] = tweening_transform_pos__to
    removeSubTemplate(eid, "tweening_transform_pos")
  else
    var t = safediv(tweening_transform_pos__timer, tweening_transform_pos__time)
    if tweening_transform_pos__lerpPow != 1.0
      t = pow(t, tweening_transform_pos__lerpPow)

    transform[3] = lerp(tweening_transform_pos__from,
                        tweening_transform_pos__to,
                        float3(t))



[es(on_appear)]
def tweening_transform_rotation_init(evt : Event;
                                     transform : float3x4;
                                     var tweening_transform_rotation__fromRot : float4&)
  tweening_transform_rotation__fromRot = float4(DagorMath::quat(transform))


[es(no_order)]
def tweening_transform_rotation(evt : ParallelUpdateFrameDelayed;
                                eid : EntityId;
                                tweening_transform_rotation__from : float4;
                                tweening_transform_rotation__to : float4;
                                tweening_transform_rotation__time : float;
                                tweening_transform_rotation__lerpPow : float;
                                var tweening_transform_rotation__timer : float&;
                                var transform : float3x4)
  tweening_transform_rotation__timer += evt.dt
  if tweening_transform_rotation__timer >= tweening_transform_rotation__time
    make_tm(quat(tweening_transform_rotation__to), transform[3], transform)
    removeSubTemplate(eid, "tweening_transform_rotation")
  else
    var t = safediv(tweening_transform_rotation__timer, tweening_transform_rotation__time)
    if tweening_transform_rotation__lerpPow != 1.0
      t = pow(t, tweening_transform_rotation__lerpPow)

    let newRot = slerp(quat(tweening_transform_rotation__from),
                       quat(tweening_transform_rotation__to),
                       t)
    make_tm(newRot, transform[3], transform)


[es(on_appear)]
def scale_to_zero_and_destroy_appear(evt : Event;
                                     eid : EntityId;
                                     scale_to_zero_and_destroy__time : float)
  tween_transform_scale_smooth(eid, float3(0.0), scale_to_zero_and_destroy__time)


[es(on_disappear, REQUIRE=(tweening_transform_scale_smooth__to, scale_to_zero_and_destroy__time))]
def scale_to_zero_and_destroy_finished(evt : Event;
                                       eid : EntityId)
  destroyEntity(eid)