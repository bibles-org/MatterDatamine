module tweening_common shared
require ecs
require DagorSystem
require DagorMath


def tween_sphere_zone_radius_smooth(eid : EntityId;
                                    radius : float;
                                    time : float)
  query(eid) <| $ [es] (sphere_zone__radius : float;
                        var tweening_sphere_zone_radius_smooth__fromRadius : float?;
                        var tweening_sphere_zone_radius_smooth__toRadius : float?;
                        var tweening_sphere_zone_radius_smooth__time : float?;
                        var tweening_sphere_zone_radius_smooth__timer : float?)
    if (tweening_sphere_zone_radius_smooth__fromRadius != null &&
        tweening_sphere_zone_radius_smooth__toRadius != null &&
        tweening_sphere_zone_radius_smooth__time != null)
      *tweening_sphere_zone_radius_smooth__fromRadius = sphere_zone__radius
      *tweening_sphere_zone_radius_smooth__toRadius = radius
      *tweening_sphere_zone_radius_smooth__time = time
      *tweening_sphere_zone_radius_smooth__timer = 0.0
    else
      addSubTemplate(eid, "tweening_sphere_zone_radius_smooth") <| $(init)
        init |> set("tweening_sphere_zone_radius_smooth__fromRadius", sphere_zone__radius)
        init |> set("tweening_sphere_zone_radius_smooth__toRadius", radius)
        init |> set("tweening_sphere_zone_radius_smooth__time", time)



def tween_transform_scale_smooth(eid : EntityId;
                                 scale : float3;
                                 time : float)
  query(eid) <| $ [es] (transform : float3x4;
                        var tweening_transform_scale_smooth__from : float3?;
                        var tweening_transform_scale_smooth__to : float3?;
                        var tweening_transform_scale_smooth__time : float?;
                        var tweening_transform_scale_smooth__timer : float?)
    let curScale = float3(length(transform[0]), length(transform[1]), length(transform[2]))
    if (tweening_transform_scale_smooth__from != null &&
        tweening_transform_scale_smooth__to != null &&
        tweening_transform_scale_smooth__time != null)
      *tweening_transform_scale_smooth__from = curScale
      *tweening_transform_scale_smooth__to = scale
      *tweening_transform_scale_smooth__time = time
      *tweening_transform_scale_smooth__timer = 0.0
    else
      addSubTemplate(eid, "tweening_transform_scale_smooth") <| $(init)
        init |> set("tweening_transform_scale_smooth__from", curScale)
        init |> set("tweening_transform_scale_smooth__to", scale)
        init |> set("tweening_transform_scale_smooth__time", time)


def tween_transform_pos(eid : EntityId;
                        to_pos : float3;
                        time : float;
                        lerp_power : float = 1.0)
  let exists = query(eid) <| $ [es] (transform : float3x4;
                                     var tweening_transform_pos__from : float3&;
                                     var tweening_transform_pos__to : float3&;
                                     var tweening_transform_pos__time : float&;
                                     var tweening_transform_pos__timer : float&;
                                     var tweening_transform_pos__lerpPow : float&)
    tweening_transform_pos__from = transform[3]
    tweening_transform_pos__to = to_pos
    tweening_transform_pos__time = time
    tweening_transform_pos__timer = 0.0
    tweening_transform_pos__lerpPow = lerp_power
  if !exists
    addSubTemplate(eid, "tweening_transform_pos") <| $(init)
      init |> set("tweening_transform_pos__to", to_pos)
      init |> set("tweening_transform_pos__time", time)
      init |> set("tweening_transform_pos__lerpPow", lerp_power)


def tween_transform_rotation(eid : EntityId;
                             to_rot : float4;
                             time : float;
                             lerp_power : float = 1.0)
  let exists = query(eid) <| $ [es] (transform : float3x4;
                                     var tweening_transform_rotation__from : float4&;
                                     var tweening_transform_rotation__to : float4&;
                                     var tweening_transform_rotation__time : float&;
                                     var tweening_transform_rotation__timer : float&;
                                     var tweening_transform_rotation__lerpPow : float&)
    tweening_transform_rotation__from = float4(DagorMath::quat(transform))
    tweening_transform_rotation__to = to_rot
    tweening_transform_rotation__time = time
    tweening_transform_rotation__timer = 0.0
    tweening_transform_rotation__lerpPow = lerp_power
  if !exists
    addSubTemplate(eid, "tweening_transform_rotation") <| $(init)
      init |> set("tweening_transform_rotation__to", to_rot)
      init |> set("tweening_transform_rotation__time", time)
      init |> set("tweening_transform_rotation__lerpPow", lerp_power)


def call_destroyer_or_destroy(eid : EntityId)
  var destroyerCalled = false
  query(eid) <| $ [es] (self_destroyer__template : string)
    if self_destroyer__template != ""
      addSubTemplate(eid, self_destroyer__template)
      destroyerCalled = true

  if !destroyerCalled
    destroyEntity(eid)
