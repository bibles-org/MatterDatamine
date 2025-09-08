require ecs
require ecs.safe
require app
require net
require math.base
require DngNet
require DngHuman
require PhysVars
require AnimV20
require GeomNodeTree
require DagorRandom
require DngPhysObj
require Grid
require DagorMath
require DagorSystem
require CollRes
require game.es.ecs_common
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.grav_zones_common
require game.es.validation_common


def can_throw_stone(eid : EntityId)
  var res = true
  query(eid) <| $ [es] (isInVehicle : bool; human_net_phys__isCrawl : bool;
                        human_net_phys__isSwimming : bool; human_weap__throwMode : bool;
                        human_inventory__entityToUse : EntityId)
    // human_inventory__entityToUse need for not interupt animation revive teammate when he is downed
    res = !isInVehicle && !human_net_phys__isCrawl && !human_net_phys__isSwimming && !human_inventory__entityToUse && !human_weap__throwMode
    find_query() <| $ [es(REQUIRE=game_effect__disableActions)] (game_effect__attachedTo : EntityId)
      if game_effect__attachedTo != eid
        return false
      res = false
      return true
  return res


[es]
def throw_stone_request(evt : RequestStartThrowStone;
                        eid : EntityId;
                        human_stone_throw__throwAnimSpeed : float;
                        human_stone_throw__effect : string;
                        human_stone_throw__throwCooldown : float;
                        human_weap_anim__throwProgressVarId : int;
                        var phys_vars : PhysVars&;
                        var human_stone_throw__throwTimer : float&)
  if is_server() && (!is_client_value_in_distance(evt.atTime, get_sync_time(), 5.0))
    logwarn("[THROWING STONE] {get_entity_info(eid)}: client event validation failed! evt={evt}")
    return

  if human_stone_throw__throwTimer > 0.f
    return
  if !can_throw_stone(eid)
    if is_server()
      send_net_event(eid, ShowStatusTip(statusTip = "status_tip_stone_throw_failed_by_pose"))
    return
  human_stone_throw__throwTimer = human_stone_throw__throwCooldown - (get_sync_time() - evt.atTime)
  createEntity(human_stone_throw__effect) <| $(var init)
    init |> set("game_effect__attachedTo", eid)
    init |> set("game_effect__clientDestroyAt", evt.atTime + human_stone_throw__throwAnimSpeed)
    init |> set("game_effect__destroyAt", evt.atTime + human_stone_throw__throwAnimSpeed)
    init |> set("stone_throwing_effect__startAt", evt.atTime)
  setVar(phys_vars, human_weap_anim__throwProgressVarId, 0.f)
  if is_server()
    send_net_event(eid, EventStartThrowStone(atTime = evt.atTime))


[es(tag=gameClient, REQUIRE_NOT=hero)]
def throw_stone_net_client(evt : EventStartThrowStone;
                           eid : EntityId;
                           human_stone_throw__throwAnimSpeed : float;
                           human_stone_throw__effect : string;
                           human_weap_anim__throwProgressVarId : int;
                           var phys_vars : PhysVars&)
  createEntity(human_stone_throw__effect) <| $(var init)
    init |> set("game_effect__attachedTo", eid)
    init |> set("game_effect__clientDestroyAt", evt.atTime + human_stone_throw__throwAnimSpeed)
    init |> set("game_effect__destroyAt", evt.atTime + human_stone_throw__throwAnimSpeed)
    init |> set("stone_throwing_effect__startAt", evt.atTime)
  setVar(phys_vars, human_weap_anim__throwProgressVarId, 0.f)


[es(no_order)]
def throw_stone_update_timer(info : ParallelUpdateFrameDelayed;
                             var human_stone_throw__throwTimer : float&)
  if human_stone_throw__throwTimer <= 0.f
    return
  human_stone_throw__throwTimer -= info.dt


[es(on_appear)]
def throw_stone_create_stone_on_appear(evt : Event;
                                       game_effect__attachedTo : EntityId;
                                       stone_throwing_effect__stoneAnimchars : StringList;
                                       stone_throwing_effect__stoneTemplate : string)
  query(game_effect__attachedTo) <| $ [es] (var human_stone_throw__curStoneEid : EntityId&)
    let stoneAnimchar = string(stone_throwing_effect__stoneAnimchars[rnd_int(0, length(stone_throwing_effect__stoneAnimchars) - 1)])
    human_stone_throw__curStoneEid = createEntity(stone_throwing_effect__stoneTemplate) <| $(var init)
      init |> set("slot_attach__attachedTo", game_effect__attachedTo)
      init |> set("throwing_stone_owner", game_effect__attachedTo)
      init |> set("animchar__res", "{stoneAnimchar}_char")
      init |> set("collres__res", "{stoneAnimchar}_collision")


[es(no_order)]
def throw_stone_update_animation(info : ParallelUpdateFrameDelayed;
                                 game_effect__attachedTo : EntityId;
                                 stone_throwing_effect__startAt : float;
                                 game_effect__destroyAt : float)
  query(game_effect__attachedTo) <| $ [es] (var phys_vars : PhysVars&;
                                            human_weap_anim__throwProgressVarId : int)
    let progress = (info.curTime - stone_throwing_effect__startAt) / (game_effect__destroyAt - stone_throwing_effect__startAt)
    setVar(phys_vars, human_weap_anim__throwProgressVarId, progress)


[es(tag=gameClient, REQUIRE=hero)]
def throw_stone_irq_reactor(evt : EventAnimIrq;
                            eid : EntityId;
                            anim_irq__eventNames : Object;
                            human_stone_throw__stoneThrowIrq : string;
                            human_net_phys : HumanActor;
                            animchar : AnimcharBaseComponent;
                            human_stone_throw__curStoneEid : EntityId)
  let irqEventObj = anim_irq__eventNames[human_stone_throw__stoneThrowIrq] ?as Object
  let irqId = irqEventObj?.irqId ?? 0
  if irqId == evt.irqType
    var tm = IDENT_TM
    query(human_stone_throw__curStoneEid) <| $ [es] (slot_attach__slotId : int)
      var tmpTm : mat44f
      if animchar_initAttachmentTmAndNodeWtm(animchar, slot_attach__slotId, tmpTm)
        let wtmOfs = *animchar.nodeTree |> geomtree_getWtmOfs()
        tm = float3x4(tmpTm)
        tm[3] += wtmOfs

        if (is_nan(tm[3]) || is_nan(human_net_phys.phys.currentState.velocity) ||
            is_nan(float3(human_net_phys.phys.currentState.location.P)) ||
            is_nan(human_net_phys.phys.producedCT.wishLookDir))
          logerr("throw_stone_irq_reactor: NaN detected!
tm={tm}
humanVelocity={human_net_phys.phys.currentState.velocity}
humanPos={human_net_phys.phys.currentState.location.P}
humanLookDir={human_net_phys.phys.producedCT.wishLookDir}")
          return

        send_net_event(eid, RequestScheduleStoneThrown(
                              transform = tm,
                              humanVelocity = human_net_phys.phys.currentState.velocity,
                              humanPos = float3(human_net_phys.phys.currentState.location.P),
                              humanLookDir = human_net_phys.phys.producedCT.wishLookDir,
                              atTick = human_net_phys.phys.currentState.atTick))
      else
        logerr("[THROWING STONE] Failed to initialize tm! slot_attach__slotId={slot_attach__slotId}")


[es]
def schedule_stone_throw(evt : RequestScheduleStoneThrown;
                         eid : EntityId;
                         transform : float3x4;
                         var human_stone_throw__atTick : int&;
                         var human_stone_throw__stoneTm : float3x4&;
                         var human_stone_throw__heroVelocity : float3&;
                         var human_stone_throw__heroPos : float3&;
                         var human_stone_throw__heroLookDir : float3&)
  if is_server() && (!is_client_value_valid(evt.atTick) ||
      !is_client_value_valid(evt.transform) || !is_client_value_in_distance(evt.transform[3], transform[3], 5.0) ||
      !is_client_value_length(evt.humanVelocity, 0.0, 10.0) ||
      !is_client_value_in_distance(evt.humanPos, transform[3], 5.0) ||
      !is_client_value_normalized(evt.humanLookDir))
    logwarn("[THROWING STONE] {get_entity_info(eid)}: client event validation failed! evt={evt}")
    return

  human_stone_throw__atTick = evt.atTick
  human_stone_throw__stoneTm = evt.transform
  human_stone_throw__heroVelocity = evt.humanVelocity
  human_stone_throw__heroPos = evt.humanPos
  human_stone_throw__heroLookDir = evt.humanLookDir
  if is_server()
    send_net_event(eid, EventScheduleStoneThrown(transform = evt.transform, humanVelocity = evt.humanVelocity, humanPos = evt.humanPos, humanLookDir = evt.humanLookDir, atTick = evt.atTick))


[es(tag=gameClient, REQUIRE_NOT=hero)]
def schedule_stone_throw_net_client(evt : EventScheduleStoneThrown;
                                    var human_stone_throw__atTick : int&;
                                    var human_stone_throw__stoneTm : float3x4&;
                                    var human_stone_throw__heroVelocity : float3&;
                                    var human_stone_throw__heroPos : float3&;
                                    var human_stone_throw__heroLookDir : float3&)
  human_stone_throw__atTick = evt.atTick
  human_stone_throw__stoneTm = evt.transform
  human_stone_throw__heroVelocity = evt.humanVelocity
  human_stone_throw__heroPos = evt.humanPos
  human_stone_throw__heroLookDir = evt.humanLookDir


def adjust_velocity(initial_velocity : float3;
                    initial_position : float3;
                    hero_position : float3;
                    hero_look_dir : float3)
  let up = -get_grav_dir(hero_position)
  let height = max(0.0, dot(initial_position - hero_position, up))
  let yVel = dot(initial_velocity, up)
  let projVel = initial_velocity - up * yVel
  let g = gravity()
  let time = yVel / g + sqrt(yVel * yVel + 2.f * g * height) / g
  let dist = length(projVel) * time
  let forward = normalize(hero_look_dir - up * dot(hero_look_dir, up))
  if sign(dot(forward, projVel)) <= 0.0
    return up * length(initial_velocity)
  // find point on forward, that has distance to initial_position equal to dist
  let toInitPosVec = initial_position - hero_position
  let initPosProj = toInitPosVec - up * dot(toInitPosVec, up)
  let angleCos = safediv(dot(forward, initPosProj), length(initPosProj))
  // dist^2 = ||initPosProj||^2 + x^2 - 2 * ||initPosProj|| * x * angleCos
  // where x is the distance (on forward) to the cross point
  // d1 = ||initPosProj||^2 * angleCos^2 - (||initPosProj||^2 - dist^2)
  // x = ||initPosProj|| * angleCos + sqrt(d1) - positive root
  let d1 = length(initPosProj) * length(initPosProj) * (angleCos * angleCos - 1.f) + dist * dist
  if d1 < 0.f
    return initial_velocity
  let x = length(initPosProj) * angleCos + sqrt(d1)
  let adjustedVelProj = normalize(forward * x - initPosProj) * length(projVel)
  let adjustedVel = adjustedVelProj + up * yVel

  if is_nan(adjustedVel)
    logerr("adjust_velocity: NaN detected!
up={up}
height={height}
g={g}
time={time}
forward={forward}
d1={d1}
x={x}
yVel={yVel}
angleCos={angleCos}
initPosProj={initPosProj}
adjustedVelProj={adjustedVelProj}
adjustedVel={adjustedVel}
initial_velocity={initial_velocity}
initial_position={initial_position}
hero_position={hero_position}
hero_look_dir={hero_look_dir}")
    return initial_velocity

  return adjustedVel


[es(after=after_net_phys_sync)]
def throw_scheduled_stone(evt : CmdPostPhysUpdate;
                          human_stone_throw__stoneTm : float3x4;
                          human_stone_throw__heroVelocity : float3;
                          human_stone_throw__heroPos : float3;
                          human_stone_throw__heroLookDir : float3;
                          human_stone_throw__curStoneEid : EntityId;
                          human_stone_throw__startVelocity : float;
                          var human_stone_throw__atTick : int&)
  if evt.tick >= human_stone_throw__atTick && human_stone_throw__atTick > 0
    query(human_stone_throw__curStoneEid) <| $ [es] (throwing_stone__attachedSubtemplate : string;
                                                     throwing_stone__physSubtemplate : string)
      removeSubTemplate(human_stone_throw__curStoneEid, throwing_stone__attachedSubtemplate)
      let physTemplate = is_server() ? throwing_stone__physSubtemplate : "{throwing_stone__physSubtemplate}+client_side"
      addSubTemplate(human_stone_throw__curStoneEid, physTemplate) <| $(var init)
        init |> set("transform", human_stone_throw__stoneTm)
        let initVel = -human_stone_throw__stoneTm[1] * human_stone_throw__startVelocity + human_stone_throw__heroVelocity
        let initPos = human_stone_throw__stoneTm[3]
        init |> set("start_vel", adjust_velocity(initVel, initPos, human_stone_throw__heroPos, human_stone_throw__heroLookDir))
    human_stone_throw__atTick = -1


[es(tag=gameClient, REQUIRE_NOT=hero, after=after_net_phys_sync)]
def throw_scheduled_stone_net_client(info : ParallelUpdateFrameDelayed;
                                     human_stone_throw__stoneTm : float3x4;
                                     human_stone_throw__heroVelocity : float3;
                                     human_stone_throw__heroPos : float3;
                                     human_stone_throw__heroLookDir : float3;
                                     human_stone_throw__curStoneEid : EntityId;
                                     human_stone_throw__startVelocity : float;
                                     human_net_phys : HumanActor;
                                     var human_stone_throw__atTick : int&)
  if human_net_phys.phys.currentState.atTick >= human_stone_throw__atTick && human_stone_throw__atTick > 0
    query(human_stone_throw__curStoneEid) <| $ [es] (throwing_stone__attachedSubtemplate : string;
                                                     throwing_stone__physSubtemplate : string)
      removeSubTemplate(human_stone_throw__curStoneEid, throwing_stone__attachedSubtemplate)
      let physTemplate = "{throwing_stone__physSubtemplate}+client_side+client_destroy_in_5_sec"
      addSubTemplate(human_stone_throw__curStoneEid, physTemplate) <| $(var init)
        init |> set("transform", human_stone_throw__stoneTm)
        let initVel = -human_stone_throw__stoneTm[1] * human_stone_throw__startVelocity + human_stone_throw__heroVelocity
        let initPos = human_stone_throw__stoneTm[3]
        init |> set("start_vel", adjust_velocity(initVel, initPos, human_stone_throw__heroPos, human_stone_throw__heroLookDir))
    human_stone_throw__atTick = -1


[es(no_order)]
def throwing_stone_freeze_update(info : ParallelUpdateFrameDelayed;
                                 eid : EntityId;
                                 throwing_stone__physSubtemplate : string;
                                 throwing_stone__freezeSubtemplate : string;
                                 transform : float3x4;
                                 var throwing_stone_phys__timeToFreeze : float&)
  throwing_stone_phys__timeToFreeze -= info.dt
  if throwing_stone_phys__timeToFreeze <= 0.f
    removeSubTemplate(eid, throwing_stone__physSubtemplate)
    addSubTemplate(eid, throwing_stone__freezeSubtemplate) <| $(var init)
      init |> set("transform", transform)
      init |> set("animchar__updatable", false)


[es(tag=server, no_order)]
def throwing_stone_monster_awake(evt : CmdPostPhysUpdate;
                                 throwing_stone__awakeCheckRadius : float;
                                 phys_obj_net_phys : PhysObjActor)
  let prevPos = float3(phys_obj_net_phys.phys.previousState.location.P)
  let curPos = float3(phys_obj_net_phys.phys.currentState.location.P)
  if length_sq(curPos - prevPos) < FLT_EPSILON
    return
  let sphere = BSphere3(curPos, throwing_stone__awakeCheckRadius)
  for_each_entity_in_grid(ecs_hash("humans"), sphere, GridEntCheck.POS) <| $(eid : EntityId)
    query(eid) <| $ [es(REQUIRE=sleeping_monster)] (collres aka monster_collres : CollisionResource;
                                                    animchar : AnimcharBaseComponent;
                                                    transform aka monster_transform : float3x4)
      let dir = normalize(curPos - prevPos)
      let t = length(curPos - prevPos)
      if collres_rayhit(monster_collres, monster_transform, animchar.nodeTree, prevPos, dir, t)
        sendEvent(eid, CmdAwakeSleepingMonster(propadateCount = 0))
  for_each_entity_in_grid(ecs_hash("am_cores"), sphere, GridEntCheck.POS) <| $(eid : EntityId)
    query(eid) <| $ [es] (collres aka monster_collres : CollisionResource;
                          animchar : AnimcharBaseComponent;
                          transform aka monster_transform : float3x4)
      let dir = normalize(curPos - prevPos)
      let t = length(curPos - prevPos)
      if collres_rayhit(monster_collres, monster_transform, animchar.nodeTree, prevPos, dir, t)
        sendEvent(eid, EventStoneHit())
