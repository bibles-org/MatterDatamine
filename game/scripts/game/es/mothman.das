require ecs
require ecs.common
require app
require net
require math.base
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.ability_enums_common
require game.es.action_common
require active_matter.game.es.ability_common
require DngNet
require DagorMath
require DngPhysObj
require PhysObj
require DngHuman
require AnimV20
require GeomNodeTree
require DngWeapon
require DaWeaponProps
require DngDm
require Grid
require Dacoll
require math.random


[es(tag=server)]
def mothman_attack_server(evt : CmdMothmanAttack;
                          eid : EntityId;
                          animchar : AnimcharBaseComponent;
                          human_cam__camNodeId : int;
                          monstrified_mothman_attack__objectPrepareCameraOffset : float3;
                          monstrified_mothman_attack__clientAttackPositionLeewayDistance : float;
                          monstrified_mothman_gathering__isChanneling : bool;
                          human_net_phys : HumanActor;
                          floating_objects__launchSpeed : float;
                          transform aka mothman_transform : float3x4;
                          hero_ability__abilities : Array;
                          var floating_objects__eids : EidList;
                          var floating_objects__numObjects : int&)
  if floating_objects__numObjects <= 0 || empty(floating_objects__eids)
    send_net_event(eid, EventUpdateMothmanAttackState(isChanneling = false, chargedAt = -1.0, chosenObject = INVALID_ENTITY_ID))
    print("[MOTHMAN] Trying to attack with <{evt.objectEid}> while don't have flying objects")
    return

  let objIndex = find_index(floating_objects__eids, evt.objectEid)
  if objIndex < 0
    print("[MOTHMAN] Trying to attack with unknown object: <{evt.objectEid}> not found in <{eid}>")
    send_net_event(eid, EventUpdateMothmanAttackState(isChanneling = false, chargedAt = -1.0, chosenObject = INVALID_ENTITY_ID))
    return

  if monstrified_mothman_gathering__isChanneling
    let abilityIdx = get_ability_index_by_name(hero_ability__abilities, "mothman_gather_stones")
    send_net_event(eid, RqCancelAbility(idx = abilityIdx))
    print("[MOTHMAN] Interrupting gathering as attack is in progress")

  let wposRel = geomtree_getNodeWposRel(*animchar.nodeTree, human_cam__camNodeId)
  let wofs = geomtree_getWtmOfs(*animchar.nodeTree)
  let cameraPos = wposRel + wofs

  var rot = float3x3(mothman_transform)
  swap(rot[2], rot[0])
  var launchPos = cameraPos + rot * monstrified_mothman_attack__objectPrepareCameraOffset
  let clientPosError = evt.position - launchPos
  let posErrorDistance = length(clientPosError)
  if posErrorDistance > 0.01
    let fixDistance = min(monstrified_mothman_attack__clientAttackPositionLeewayDistance, posErrorDistance)
    launchPos += clientPosError / posErrorDistance * fixDistance

  let initialVelocity = evt.direction * floating_objects__launchSpeed + human_net_phys.phys.currentState.velocity

  let entityTempl = evt.charged ? "mothman_server_launched_teleport" : "mothman_server_launched_object"
  let serverPhysEid = createEntity(entityTempl) <| $(init)
    var tm = IDENT_TM
    tm[3] = launchPos
    set(init, "floating_object__owner", eid)
    set(init, "transform", tm)
    set(init, "start_vel", initialVelocity)
    set(init, "mothman_server_launched_object__attachedClientEntity", evt.objectEid)
    set(init, "mothman_server_launched_object__catchupFromTime", evt.shotAt)
    using() <| $(var toIgnoreList : EidList)
      push(toIgnoreList, eid)
      set(init, "ignoreObjs__eids", toIgnoreList)

  floating_objects__numObjects -= 1
  print("[MOTHMAN] Launched object <{evt.objectEid}>(index {objIndex}) from <{eid}>. Phys eid = {serverPhysEid}")
  erase(floating_objects__eids, objIndex)
  send_net_event(eid, EventUpdateMothmanAttackState(isChanneling = false, chargedAt = -1.0, chosenObject = INVALID_ENTITY_ID))


[es(tag=server, on_appear)]
def server_launched_object_catchup_on_server(evt : Event;
                                             mothman_server_launched_object__catchupFromTime : float;
                                             floating_object__owner : EntityId;
                                             var phys_obj_net_phys : PhysObjActor)
  query(floating_object__owner) <| $ [es] (monstrified_mothman_attack__clientAttackMaxLeewayTime : float)
    let serverTime = get_sync_time()
    let clientTime = mothman_server_launched_object__catchupFromTime
    let timeDiff = clamp((serverTime - clientTime) * 2.0, 0.0, monstrified_mothman_attack__clientAttackMaxLeewayTime)
    let catchupDt = 0.05
    var catchingTime = serverTime - timeDiff
    while catchingTime < serverTime && !phys_obj_net_phys.phys.currentState.hadContact
      phys_obj_net_phys.phys |> updatePhys(catchingTime, catchupDt, true)
      catchingTime += catchupDt


[es(tag=server, on_disappear, REQUIRE_NOT=mothman_hero_client_prediction_launched_object)]
def cleanup_clientside_mothman_object(evt : Event; mothman_server_launched_object__attachedClientEntity : EntityId)
  destroyEntity(mothman_server_launched_object__attachedClientEntity)


[es(tag=server, no_order)]
def mothman_gather_update(upd : UpdateStageInfoAct;
                          eid : EntityId;
                          monstrified_mothman_gathering__isChanneling : bool;
                          monstrified_mothman_gathering__maxGatheredItems : int;
                          monstrified_mothman_gathering__oneItemGatherTime : float;
                          hero_ability__abilities : Array;
                          var floating_objects__numObjects : int&;
                          var monstrified_mothman_gathering__nextGatherAt : float&)
  if !monstrified_mothman_gathering__isChanneling
    monstrified_mothman_gathering__nextGatherAt = -1.0
    return

  if floating_objects__numObjects >= monstrified_mothman_gathering__maxGatheredItems
    let abilityIdx = get_ability_index_by_name(hero_ability__abilities, "mothman_gather_stones")
    send_net_event(eid, RqCancelAbility(idx = abilityIdx))
    monstrified_mothman_gathering__nextGatherAt = -1.0
    return

  if monstrified_mothman_gathering__nextGatherAt < 0.0
    monstrified_mothman_gathering__nextGatherAt = upd.curTime + monstrified_mothman_gathering__oneItemGatherTime
    return

  if monstrified_mothman_gathering__nextGatherAt < 0.0 || upd.curTime < monstrified_mothman_gathering__nextGatherAt
    return

  monstrified_mothman_gathering__nextGatherAt = upd.curTime + monstrified_mothman_gathering__oneItemGatherTime
  floating_objects__numObjects += 1


[es(tag=server, on_appear, track=monstrified_mothman_gathering__isChanneling)]
def mothman_verify_gathering(evt : Event;
                             eid : EntityId;
                             monstrified_mothman_gathering__isChanneling : bool;
                             monstrified_mothman_gathering__maxHeight : float;
                             hero_ability__abilities : Array;
                             monstrified_mothman__isNearGround : bool;
                             monstrified_mothman__currentHeightNearGround : float)
  if !monstrified_mothman_gathering__isChanneling
    return

  if !monstrified_mothman__isNearGround || monstrified_mothman__currentHeightNearGround > monstrified_mothman_gathering__maxHeight
    let abilityIdx = get_ability_index_by_name(hero_ability__abilities, "mothman_gather_stones")
    send_net_event(eid, RqCancelAbility(idx = abilityIdx))
    send_net_event(eid, ShowStatusTip(statusTip = "status_tip_mothman_too_high_to_gather"))
    send_net_event(eid, AbilityUseFailed(ability_name = "mothman_gather_stones", reason = int(AbilityUseFailedReason.TOO_FAR)))

[es(tag=server, no_order)]
def mothman_track_height(upd : UpdateStageInfoAct;
                         var human_net_phys : HumanActor;
                         transform aka mothman_transform : float3x4;
                         monstrified_mothman__maxTraceHeight : float;
                         var monstrified_mothman__isNearGround : bool&;
                         var monstrified_mothman__currentHeightNearGround : float&)
  let tracePos = mothman_transform[3] + mothman_transform[1] * 0.5
  let finalPos = tracePos - mothman_transform[1] * monstrified_mothman__maxTraceHeight

  var queryOut = ShapeQueryOutput()
  let DEFAULT_SPHERE_CAST_MASK = int(PhysLayer.EPL_ALL) & ~(int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_KINEMATIC) | int(PhysLayer.EPL_DEBRIS))
  monstrified_mothman__isNearGround = sphere_cast_ex(tracePos, finalPos, human_net_phys.phys.walkRad,
                                                     queryOut, human_net_phys.phys.rayMatId, human_net_phys.phys.torsoCollision,
                                                     human_net_phys.phys |> human_phys_getTraceHandle(), DEFAULT_SPHERE_CAST_MASK)
  if monstrified_mothman__isNearGround
    monstrified_mothman__currentHeightNearGround = length(queryOut.res - tracePos)
  else
    monstrified_mothman__currentHeightNearGround = monstrified_mothman__maxTraceHeight



[es(tag=server, no_order)]
def mothman_track_distance_to_ceiling(upd : UpdateStageInfoAct;
                                      var human_net_phys : HumanActor;
                                      transform aka mothman_transform : float3x4;
                                      monstrified_mothman__maxTraceLenCeiling : float;
                                      var monstrified_mothman__distToCeiling : float&)
  let tracePos = mothman_transform[3] + mothman_transform[1] * 0.5
  let finalPos = tracePos + mothman_transform[1] * monstrified_mothman__maxTraceLenCeiling

  var queryOut = ShapeQueryOutput()
  let DEFAULT_SPHERE_CAST_MASK = int(PhysLayer.EPL_ALL) & ~(int(PhysLayer.EPL_CHARACTER) | int(PhysLayer.EPL_KINEMATIC) | int(PhysLayer.EPL_DEBRIS))
  if sphere_cast_ex(tracePos, finalPos, human_net_phys.phys.walkRad,
                    queryOut, human_net_phys.phys.rayMatId, human_net_phys.phys.torsoCollision,
                    human_net_phys.phys |> human_phys_getTraceHandle(), DEFAULT_SPHERE_CAST_MASK)
    monstrified_mothman__distToCeiling = length(queryOut.res - tracePos)
  else
    monstrified_mothman__distToCeiling = monstrified_mothman__maxTraceLenCeiling


[es(tag=server, after=(mothman_track_distance_to_ceiling, mothman_track_height))]
def mothman_disable_flight(upd : UpdateStageInfoAct;
                           monstrified_mothman__minDistToCeiling : float;
                           monstrified_mothman__distToCeiling : float;
                           monstrified_mothman__isNearGround : bool;
                           var monster_flight_mode__enabled : bool&)
  monster_flight_mode__enabled = monstrified_mothman__isNearGround && monstrified_mothman__distToCeiling > monstrified_mothman__minDistToCeiling


[es(tag=server)]
def mothman_attack_request(evt : CmdMothmanChannelAttack; eid : EntityId)
  send_net_event(eid, EventUpdateMothmanAttackState(isChanneling = true, chargedAt = evt.chargeAt, chosenObject = evt.objectEid))


[es(tag=server)]
def mothman_cancel_attack_request(evt : CmdMothmanCancelAttack; eid : EntityId)
  send_net_event(eid, EventUpdateMothmanAttackState(isChanneling = false, chargedAt = -1.0, chosenObject = INVALID_ENTITY_ID))


[es(tag=server, on_appear, REQUIRE=mothman_locate_players_ability_activated)]
def mothman_locate_players_ability_activated(evt : Event;
                                             game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (eid aka mothman_eid : EntityId; transform aka mothman_transform : float3x4)
    var chosenEnemyPos : float3
    var chosenEnemyDistanceSq = FLT_MAX
    query() <| $ [es(REQUIRE_NOT=deadEntity)] (possessedByPlr : EntityId; transform : float3x4; eid : EntityId)
      if possessedByPlr == INVALID_ENTITY_ID || eid == mothman_eid
        return
      let curDistanceSq = distance_sq(transform[3], mothman_transform[3])
      if curDistanceSq < chosenEnemyDistanceSq
        chosenEnemyDistanceSq = curDistanceSq
        chosenEnemyPos = transform[3]

    if chosenEnemyDistanceSq >= FLT_MAX
      chosenEnemyPos = mothman_transform[3] + float3(0.0, 100.0, 0.0)
    send_net_event(mothman_eid, EventLightningCreated(startPos = mothman_transform[3] + mothman_transform[0] * 10.0,
                                                          direction = normalize(chosenEnemyPos - mothman_transform[3]),
                                                          speed = 50.0,
                                                          lifetime = 8.0))


[es(track=monster_flight_mode__isSprinting, on_appear)]
def cancel_gather_on_sprint(evt : Event;
                            eid : EntityId;
                            monster_flight_mode__isSprinting : bool;
                            hero_ability__abilities : Array;
                            var monstrified_mothman_gathering__nextGatherAt : float&)
  if monster_flight_mode__isSprinting
    let abilityIdx = get_ability_index_by_name(hero_ability__abilities, "mothman_gather_stones")
    send_net_event(eid, RqCancelAbility(idx = abilityIdx))
    monstrified_mothman_gathering__nextGatherAt = -1.0


[es(tag=server, REQUIRE=mothman_server_launched_teleport)]
def floating_object_attack_teleport_on_contact(evt : EventFirstContact;
                                               shell__shell_id__shell_id : int;
                                               shell__shell_id__damage_id : int;
                                               shell__shell_id__ballistics_id : int;
                                               floating_object__owner : EntityId;
                                               phys_obj_net_phys : PhysObjActor;
                                               eid : EntityId)
  destroyEntity(eid)
  using() <| $(var shellId : ShellPropIds#)
    shellId.shellId = int16(shell__shell_id__shell_id)
    shellId.damageId = int16(shell__shell_id__damage_id)
    shellId.ballisticsId = int16(shell__shell_id__ballistics_id)
    assume velocity = phys_obj_net_phys.phys.currentState.velocity
    let pos = float3(phys_obj_net_phys.phys.currentState.location.P)

    let normal = float3()
    detonate_shell_server(eid, shellId, -1, pos,
                          floating_object__owner, pos,
                          velocity, floating_object__owner,
                          normal, INVALID_ENTITY_ID)
    let maxRadius = get_shell_max_radius(shell__shell_id__shell_id, shell__shell_id__damage_id, shell__shell_id__ballistics_id)
    for_each_entity_in_grid(ecs_hash("humans"), BSphere3(pos, maxRadius), GridEntCheck.BOUNDING) <| $(militantEid : EntityId)
      createEntity("mothman_teleport_affect") <| $(init)
        set(init, "game_effect__attachedTo", militantEid)
        set(init, "teleport_trap_affect__center", pos)


[es(tag=server, on_appear)]
def mothman_idle_sound_init(evt : Event;
                            mothman_idle_sound__periodMinMax : float2;
                            var mothman_idle_sound__nextAt : float&)
  mothman_idle_sound__nextAt = get_sync_time() + mothman_idle_sound__periodMinMax.y


[es(tag=server, on_appear, REQUIRE=reset_mothman_idle_sound)]
def mothman_reset_idle_sound_game_effect(evt : Event; game_effect__attachedTo : EntityId)
  query(game_effect__attachedTo) <| $ [es] (mothman_idle_sound__periodMinMax : float2;
                                            var mothman_idle_sound__nextAt : float&)
    mothman_idle_sound__nextAt = get_sync_time() + rnd_float(mothman_idle_sound__periodMinMax)


[es(tag=server, before=mothman_idle_sound_update)]
def mothman_idle_sound_reset_on_sprint(upd : UpdateStageInfoAct;
                                       monster_flight_mode__isSprinting : bool;
                                       mothman_idle_sound__periodMinMax : float2;
                                       var mothman_idle_sound__nextAt : float&)
  if monster_flight_mode__isSprinting
    mothman_idle_sound__nextAt = upd.curTime + rnd_float(mothman_idle_sound__periodMinMax)


[es(tag=server, track=floating_objects__numObjects, REQUIRE=floating_objects__numObjects)]
def mothman_idle_sound_reset_on_object_launched_or_gathered(evt : Event;
                                                            mothman_idle_sound__periodMinMax : float2;
                                                            var mothman_idle_sound__nextAt : float&)
  mothman_idle_sound__nextAt = get_sync_time() + rnd_float(mothman_idle_sound__periodMinMax)


[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def mothman_idle_sound_update(upd : UpdateStageInfoAct;
                              eid : EntityId;
                              mothman_idle_sound__periodMinMax : float2;
                              var mothman_idle_sound__nextAt : float&)
  if upd.curTime < mothman_idle_sound__nextAt
    return

  mothman_idle_sound__nextAt = upd.curTime + rnd_float(mothman_idle_sound__periodMinMax)
  send_net_event(eid, CmdPlayMothmanIdleSound())


[es(tag=server, track=isAlive)]
def destroy_mothman_floating_objects_on_death(evt : Event;
                                              isAlive : bool;
                                              var floating_objects__eids : EidList)
  if isAlive
    return
  let now = get_sync_time()
  for eid in floating_objects__eids
    remote_add_sub_template(eid, "mothman_floating_object_destruction") <| $(i)
      set(i, "mothman_floating_object_destruction__destroyAt", now + rnd_float(0.0, 5.0))


[es(no_order, tag=server)]
def mothman_floating_object_delayed_destruction_server(upd : UpdateStageInfoAct;
                                                       eid : EntityId;
                                                       mothman_floating_object_destruction__destroyAt : float)
  if upd.curTime > mothman_floating_object_destruction__destroyAt
    destroyEntity(eid)