require ecs
require app
require math.base
require math.ang
require HumanPhys
require game.events.events
require game.utils.hero
require DngHuman
require DagorMath
require game.events.events_game
require game.es.game_effect_macro


[es(tag=server)]
def disoriented_anomaly_enter(evt : EventZoneEnter; eid : EntityId;
                              disoriented_anomaly__affectTemplate : string)
  createEntity(disoriented_anomaly__affectTemplate) <| $(init)
    set(init, "game_effect__attachedTo", evt.visitorEid)
    set(init, "anomaly_effect__ownerAnomalyEid", eid)


[es(tag=server, no_order, REQUIRE=disorientedAnomalyEffect)]
def disoriented_effect_update_server(act : UpdateStageInfoAct; eid, game_effect__attachedTo, anomaly_effect__ownerAnomalyEid : EntityId)
  query(game_effect__attachedTo) <| $ [es] (transform aka human_transform : float3x4)
    query(anomaly_effect__ownerAnomalyEid) <| $ [es] (transform : float3x4; sphere_zone__radius : float)
      if distance_sq(human_transform[3], transform[3]) > square(sphere_zone__radius * 1.1)
        destroyEntity(eid)


[es_game_effect(bool_flag=human_effect__disorientedAnomaly, tag=disorientedAnomalyEffect)]
def disoriented_anomaly_es() { pass; }


[es(tag=input, after=human_input_es, REQUIRE=disorientedAnomalyEffect)]
def disoriented_effect_update_client(act : UpdateStageUpdateInput; game_effect__attachedTo, anomaly_effect__ownerAnomalyEid : EntityId)
  query(game_effect__attachedTo) <| $ [es(REQUIRE=human_input)] (transform aka human_transform : float3x4;
                                                                 human_net_phys : HumanActor;
                                                                 var human_input__aimAngle : float2&)
    assume state = human_net_phys.phys
    if state.producedCT.walkSpeed == 0.0
      return
    query(anomaly_effect__ownerAnomalyEid) <| $ [es] (transform : float3x4;
                                                      disoriented_anomaly__sprintMultiplier : float;
                                                      disoriented_anomaly__angle : float)
      let dir = transform[3] - human_transform[3]
      let dstSq = max(1.0, length_sq(float2(dir.x, dir.z)))
      var angle = safediv(disoriented_anomaly__angle, dstSq)
      let isSprinting = (int(human_net_phys.phys.currentState.states) & int(StateFlag.ST_SPRINT)) != 0
      if isSprinting
        angle *= disoriented_anomaly__sprintMultiplier
      human_input__aimAngle.x += angle * act.dt

//require DagorDebug3D
//require DagorMath
//[es(tag=gameClient, no_order, REQUIRE=disoriented_anomaly__affectTemplate)]
//def draw_disoriented_anomaly(act : UpdateStageInfoAct; transform : float3x4)
//  draw_debug_sphere_buffered(transform[3], 0.5, E3DCOLOR(0xffffffff), 12, 1)
