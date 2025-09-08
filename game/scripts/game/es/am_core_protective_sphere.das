require ecs
require DagorMath
require math.base
require game.es.tweening_common
require game.events.events_active_matter
require DagorSystem


[es(tag=gameClient, on_appear)]
def am_core_bulletproof_sphere_appear_client(evt : Event;
                                             eid aka sphere_eid : EntityId;
                                             transform aka sphere_transform : float3x4;
                                             am_core_bulletproof_sphere__visualTemplate : string;
                                             var am_core_bulletproof_sphere__visualEid : EntityId&)
  am_core_bulletproof_sphere__visualEid = createEntity(am_core_bulletproof_sphere__visualTemplate) <| $(var init : ComponentsInitializer)
    var tm = sphere_transform
    find_query() <| $ [es] (am_core__protectiveSphereEid : EntityId;
                            am_core__protectiveSphereVisualScale : float;
                            am_core__protectiveSphereRadiusMinMax : float2;
                            am_core__protectiveSphereEnabled : bool)
      if am_core__protectiveSphereEid == sphere_eid
        assume enabled = am_core__protectiveSphereEnabled
        assume radiusMinMax = am_core__protectiveSphereRadiusMinMax
        let currentRadius = enabled ? radiusMinMax.y : radiusMinMax.x
        let visualScale = am_core__protectiveSphereVisualScale * currentRadius
        tm = scale_tm(float3(visualScale))
        tm[3] = sphere_transform[3]
        return true
      return false
    init |> set("transform", tm)


[es(tag=gameClient, on_disappear)]
def am_core_bulletproof_sphere_disappear_client(evt : Event;
                                                var am_core_bulletproof_sphere__visualEid : EntityId&)
  destroyEntity(am_core_bulletproof_sphere__visualEid)
  am_core_bulletproof_sphere__visualEid = INVALID_ENTITY_ID


[es(tag=gameClient, no_order)]
def am_core_bulletproof_sphere_update_client(act : ParallelUpdateFrameDelayed;
                                             transform aka sphere_transform : float3x4;
                                             am_core_bulletproof_sphere__visualEid : EntityId)
  query(am_core_bulletproof_sphere__visualEid) <| $ [es] (var transform aka visual_transform : float3x4)
    visual_transform[3] = sphere_transform[3]


[es(tag=server, on_appear)]
def am_core_protective_sphere_init(evt : Event;
                                   eid : EntityId;
                                   am_core__protectiveSphereTemplate : string;
                                   transform : float3x4;
                                   am_core__protectiveSphereVisualScale : float;
                                   am_core__protectiveSphereRadiusMinMax : float2;
                                   am_core__protectiveSphereEnabled : bool;
                                   var am_core__protectiveSphereEid : EntityId&)
  am_core__protectiveSphereEid = createEntity(am_core__protectiveSphereTemplate) <| $(init)
    assume enabled = am_core__protectiveSphereEnabled
    assume radiusMinMax = am_core__protectiveSphereRadiusMinMax
    let currentRadius = enabled ? radiusMinMax.y : radiusMinMax.x
    let visualScale = am_core__protectiveSphereVisualScale * currentRadius
    var tm = scale_tm(float3(visualScale))
    tm[3] = transform[3]
    init |> set("am_core_protective_sphere__ownerEid", eid)
    init |> set("transform", tm)
    init |> set("sphere_zone__radius", currentRadius)


[es(tag=server, on_disappear)]
def am_core_protective_sphere_disappear(evt : Event;
                                        am_core__protectiveSphereEid : EntityId)
  destroyEntity(am_core__protectiveSphereEid)


[es(no_order, REQUIRE=am_core_protective_sphere)]
def am_core_protective_sphere_update(info : ParallelUpdateFrameDelayed;
                                     am_core_protective_sphere__ownerEid : EntityId;
                                     var transform aka protective_shield_transform : float3x4)
  query(am_core_protective_sphere__ownerEid) <| $ [es] (transform aka owner_shield_transform : float3x4;
                                                        am_core__protectiveSphereAttached : bool = true)
    if am_core__protectiveSphereAttached
      protective_shield_transform[3] = owner_shield_transform[3]

[es(after=am_core_protective_sphere_update)]
def am_core_protective_sphere_update_client(info : ParallelUpdateFrameDelayed;
                                            am_core_protective_sphere__rotationSpd : float3;
                                            var transform : float3x4)
  var rotation : quat
  assume rotSpd = am_core_protective_sphere__rotationSpd
  euler_to_quat(deg_to_rad(rotSpd.x * info.dt), deg_to_rad(rotSpd.y * info.dt), deg_to_rad(rotSpd.z * info.dt), rotation)
  var rotationTm : float3x4
  make_tm(rotation, rotationTm)
  transform = transform * rotationTm


[es(track=am_core__protectiveSphereEnabled)]
def am_core_protective_sphere_track_enabled(evt : Event;
                                            am_core__protectiveSphereEid : EntityId;
                                            am_core__protectiveSphereEnabled : bool;
                                            am_core__protectiveSphereVisualScale : float;
                                            am_core__protectiveSphereRadiusMinMax : float2;
                                            am_core__protectiveSphereScaleTime : float = 0.35)
  assume enabled = am_core__protectiveSphereEnabled

  let radius = enabled ? am_core__protectiveSphereRadiusMinMax.y : am_core__protectiveSphereRadiusMinMax.x
  tween_sphere_zone_radius_smooth(am_core__protectiveSphereEid, radius, am_core__protectiveSphereScaleTime)

  query(am_core__protectiveSphereEid) <| $ [es] (am_core_bulletproof_sphere__visualEid : EntityId)
    let visualScale = am_core__protectiveSphereVisualScale * radius
    tween_transform_scale_smooth(am_core_bulletproof_sphere__visualEid, float3(visualScale), am_core__protectiveSphereScaleTime)