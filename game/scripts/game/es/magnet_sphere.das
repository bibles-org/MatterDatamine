require ecs
require ecs.common
require app
require game.events.events_game
require math.base
require PhysObj
require DngPhysObj
require DngHuman
require DagorMath


[es(tag=server)]
def magnet_sphere_zone_enter(evt : EventZoneEnter;
                             eid aka magnet_sphere_eid : EntityId;
                             magnet_sphere__magnetEffect : string)
  let found = find_query() <| $ [es] (game_effect__attachedTo : EntityId;
                                      magnet_sphere_effect__magnetSphereEid : EntityId)
    return magnet_sphere_effect__magnetSphereEid == magnet_sphere_eid && game_effect__attachedTo == evt.visitorEid

  if found
    return

  createEntity(magnet_sphere__magnetEffect) <| $ [es] (var init : ComponentsInitializer)
    init |> set("game_effect__attachedTo", evt.visitorEid)
    init |> set("magnet_sphere_effect__magnetSphereEid", magnet_sphere_eid)


[es(tag=server)]
def magnet_sphere_zone_leave(evt : EventZoneLeave;
                             eid aka magnet_sphere_eid : EntityId)
  find_query() <| $ [es] (eid aka effect_eid : EntityId;
                          game_effect__attachedTo : EntityId;
                          magnet_sphere_effect__magnetSphereEid : EntityId)
    if magnet_sphere_effect__magnetSphereEid == magnet_sphere_eid && game_effect__attachedTo == evt.visitorEid
      destroyEntity(effect_eid)
      return true

    return false


[es(tag=server, no_order)]
def magnet_sphere_effect_update(act : UpdateStageInfoAct;
                                magnet_sphere_effect__magnetSphereEid : EntityId;
                                game_effect__attachedTo : EntityId)
  query(magnet_sphere_effect__magnetSphereEid) <| $ [es] (transform aka magnet_sphere_transform : float3x4;
                                                          sphere_zone__radius : float;
                                                          magnet_sphere__innerSphereRadiusFactor : float;
                                                          magnet_sphere__innerPushForce : float;
                                                          magnet_sphere__outerPushForce : float;
                                                          magnet_sphere__powFactor : float)
    query(game_effect__attachedTo) <| $ [es] (transform aka human_transform : float3x4;
                                              var human_net_phys : HumanActor)
      let innerRadius = sphere_zone__radius * magnet_sphere__innerSphereRadiusFactor

      let actorPos = human_transform[3] + human_transform[1]
      let magnetSphere = magnet_sphere_transform[3]
      let distSq = distance_sq(actorPos, magnetSphere)
      if distSq < square(1e-3)
        return

      let dist = sqrt(distSq)
      let pushDir = (actorPos - magnetSphere) / dist

      let koef = pow(cvt(dist, innerRadius, sphere_zone__radius, 0.0, 1.0), magnet_sphere__powFactor)
      let pushForce = lerp(magnet_sphere__innerPushForce, magnet_sphere__outerPushForce, koef)

      human_net_phys.phys.currentState.velocity += pushDir * pushForce * act.dt
