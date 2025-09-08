require ecs
require app
require DngNet
require RendInst
require Grid
require Dacoll
require AnimV20
require GeomNodeTree
require DagorSystem
require math.base
require DagorMath
require game.es.riextra_common
require game.events.events_game
require game.events.vehicle_events


[es(tag=server, on_appear, REQUIRE=monster_explode)]
def make_pushing_explosion(evt : Event;
                           eid : EntityId;
                           game_effect__attachedTo : EntityId;
                           monster_explosion__pushForce : float;
                           monster_explosion__traceNode : string;
                           monster_explosion__pushForceVehicle : float;
                           monster_explosion__pushUpForce : float;
                           monster_explosion__riDmgRadius : float;
                           monster_explosion__riDmgNearFar : float2;
                           sphere_zone__radius : float)
  query(game_effect__attachedTo) <| $[es] (transform aka monster_transform : float3x4;
                                           animchar : AnimcharBaseComponent;
                                           possessedByPlr : EntityId)
    let influenceSphere = BSphere3(transform[3], sphere_zone__radius)
    var nodeId = *animchar.nodeTree |> geomtree_findNodeIndex(monster_explosion__traceNode)
    if nodeId < 0
      logerr("Pushing ability node unknown position: {monster_explosion__traceNode} nodeId < 0")
      return
    var nodeTm : float3x4
    *animchar.nodeTree |> geomtree_getNodeWtmScalar(nodeId, nodeTm)
    let traceFrom = nodeTm[3]
    for_each_entity_in_grid(ecs_hash("humans"), influenceSphere, GridEntCheck.BOUNDING) <| $(human_eid : EntityId; human_pos : float3)
      var traceTo = human_pos
      query(human_eid) $ [es] (animchar : AnimcharBaseComponent)
        nodeId = *animchar.nodeTree |> geomtree_findNodeIndex(monster_explosion__traceNode)
        if nodeId < 0
          logerr("Pushing ability node unknown position: {monster_explosion__traceNode} nodeId < 0")
          return
        *animchar.nodeTree |> geomtree_getNodeWtmScalar(nodeId, nodeTm)
        traceTo = nodeTm[3]
      let vec = traceTo - traceFrom
      let t = length(vec)
      let dirToVictim = vec * safeinv(t)
      if game_effect__attachedTo == human_eid || rayhit_normalized(traceFrom, dirToVictim, t, ETF_DEFAULT, -1)
        return
      let dir = normalize(x0z(human_pos - transform[3]) + float3(0.0, monster_explosion__pushUpForce, 0.0))
      sendEvent(human_eid, CmdPushPhys(vel = dir * monster_explosion__pushForce, push_immunity = 0.0))
    for_each_entity_in_grid(ecs_hash("vehicles"), influenceSphere, GridEntCheck.BOUNDING) <| $(vehicle_eid : EntityId; vehicle_pos : float3)
      let dir = normalize(x0z(vehicle_pos - transform[3]) + float3(0.0, monster_explosion__pushUpForce, 0.0))
      sendEvent(vehicle_eid, CmdVehiclePushPhys(
        energyScaledDir = dir * monster_explosion__pushForceVehicle,
        arm = transform[3],
        duration = 0.0
      ))
    query(possessedByPlr) <| $[es] (team : int)
      damage_ri_in_sphere(transform[3],
                          monster_explosion__riDmgRadius,
                          monster_explosion__riDmgNearFar,
                          get_sync_time(), !is_true_net_server(),
                          $(riex_handle : riex_handle_t){ riex_set_offender(riex_handle, eid); },
                          $(riex_handle : riex_handle_t){ return riex_should_damage(eid, team, riex_handle); })
  destroyEntity(eid)


[es(tag=gameClient, on_disappear, REQUIRE=monster_explode)]
def create_fx_for_pushing_explode(evt : Event;
                                  game_effect__attachedTo : EntityId;
                                  monster_explosion__fxTemplate : string)
  query(game_effect__attachedTo) <| $[es] (transform : float3x4)
    createEntity(monster_explosion__fxTemplate) <| $(init)
      init |> set("transform", transform)