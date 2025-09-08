require ecs
require app
require net
require math.base
require game.events.events
require game.events.events_game
require game.events.events_active_matter
require game.es.action_common
require DngNet
require DngCamera
require DngPhysObj
require DngHuman
require DagorMath


[es(tag=gameClient, track=monstrified_mothman_attack__isChanneling, REQUIRE=hero)]
def mothman_attack_control(evt : Event;
                           eid : EntityId;
                           monstrified_mothman_attack__isChanneling : bool;
                           monstrified_mothman_attack__loadTime : float;
                           var monstrified_mothman_attack__chosenObject : EntityId&;
                           floating_objects__eids : EidList;
                           monstrified_mothman_attack__shootAnimTime : float;
                           var monstrified_mothman_attack__shootAnimTimeEnd : float&;
                           var monstrified_mothman_attack__chargedAt : float&)
  let curTime = get_sync_time()

  if monstrified_mothman_attack__isChanneling && length(floating_objects__eids) > 0
    monstrified_mothman_attack__chargedAt = curTime + monstrified_mothman_attack__loadTime
    monstrified_mothman_attack__chosenObject = floating_objects__eids[0]
    send_net_event(eid, CmdMothmanChannelAttack(chargeAt = monstrified_mothman_attack__chargedAt, objectEid = monstrified_mothman_attack__chosenObject))
    return

  var camTm = IDENT_TM
  let curCam = get_cur_cam_entity()
  query(curCam) <| $ [es] (transform : float3x4)
    camTm = transform

  let isCharged = (monstrified_mothman_attack__chargedAt > 0.0 && curTime >= monstrified_mothman_attack__chargedAt)

  monstrified_mothman_attack__chargedAt = -1.0
  query(monstrified_mothman_attack__chosenObject) <| $ [es] (transform aka object_transform : float3x4)
    send_net_event(eid, CmdMothmanAttack(direction = camTm[2],
                                          position = object_transform[3],
                                          shotAt = curTime,
                                          objectEid = monstrified_mothman_attack__chosenObject,
                                          charged = isCharged))
    monstrified_mothman_attack__shootAnimTimeEnd = curTime + monstrified_mothman_attack__shootAnimTime
  monstrified_mothman_attack__chosenObject = INVALID_ENTITY_ID


[es(tag=netClient, REQUIRE=hero)]
def controlling_client_predict_thrown_object(evt : CmdMothmanAttack;
                                             eid : EntityId;
                                             floating_objects__launchSpeed : float;
                                             human_net_phys : HumanActor)
  let predictionEid = createEntity("mothman_hero_client_prediction_launched_object") <| $(init)
    var tm = IDENT_TM
    tm[3] = evt.position
    set(init, "floating_object__owner", eid)
    set(init, "transform", tm)
    assume velocity = evt.direction * floating_objects__launchSpeed + human_net_phys.phys.currentState.velocity
    set(init, "start_vel", velocity)
    set(init, "mothman_server_launched_object__attachedClientEntity", evt.objectEid)
  print("[MOTHMAN] predicting thrown object {predictionEid} for floating object {evt.objectEid}")


def private reset_attack_charge(eid : EntityId)
  query(eid) <| $ [es] (var monstrified_mothman_attack__chargedAt : float&; var monstrified_mothman_attack__shotAt : float&)
    monstrified_mothman_attack__chargedAt = -1.0
    monstrified_mothman_attack__shotAt = get_sync_time()


[es(tag=netClient, on_appear, REQUIRE=mothman_server_launched_object__attachedClientEntity, REQUIRE_NOT=mothman_hero_client_prediction_launched_object)]
def mothman_reset_attack_charge_on_server_acknolegement(evt : Event;
                                                        floating_object__owner : EntityId)
  if !has(floating_object__owner, "hero")
    print("[MOTHMAN] Reset attack state for <{floating_object__owner}> (not hero)")
    reset_attack_charge(floating_object__owner)


[es(tag=netClient, on_appear, REQUIRE=mothman_hero_client_prediction_launched_object)]
def mothman_reset_attack_charge_on_prediction_creation(evt : Event;
                                                       floating_object__owner : EntityId)
  print("[MOTHMAN] prediction appeared for <{floating_object__owner}>. (is hero = {has(floating_object__owner, "hero")})")
  if has(floating_object__owner, "hero")
    print("[MOTHMAN] Reset attack state for <{floating_object__owner}> (hero)")
    reset_attack_charge(floating_object__owner)


[es(tag=(gameClient, server), on_appear, REQUIRE=mothman_server_launched_object__attachedClientEntity)]
def mothman_reset_attack_charge_in_offline(evt : Event; floating_object__owner : EntityId)
  print("[MOTHMAN] Reset attack state for <{floating_object__owner}> (offline)")
  reset_attack_charge(floating_object__owner)


[es(tag=gameClient, no_order)]
def client_update_mothman_launched_object(upd : UpdateStageInfoAct;
                                          mothman_clientside_launched_object__attachedServerEntity : EntityId;
                                          mothman_clientside_launched_object__launchedAt : float;
                                          mothman_clientside_launched_object__catchupTime : float;
                                          var transform aka rendinst_transform : float3x4&)
  query(mothman_clientside_launched_object__attachedServerEntity) <| $ [es] (transform aka phys_transform : float3x4)
    let t = min(1.0, (upd.curTime - mothman_clientside_launched_object__launchedAt) / mothman_clientside_launched_object__catchupTime)
    if t >= 1.0
      rendinst_transform[3] = phys_transform[3]
      return
    let catchupOffset = (phys_transform[3] - rendinst_transform[3]) * t
    rendinst_transform[3] += catchupOffset


[es(on_appear, tag=gameClient)]
def client_init_mothman_launched_object(evt : Event;
                                        eid aka phys_eid : EntityId;
                                        mothman_hero_client_prediction_launched_object : Tag const?;
                                        mothman_server_launched_object__attachedClientEntity : EntityId)
  if mothman_hero_client_prediction_launched_object == null
    assume newAttached = mothman_server_launched_object__attachedClientEntity
    find_query() <| $ [es(REQUIRE=mothman_hero_client_prediction_launched_object)] (mothman_server_launched_object__attachedClientEntity : EntityId; eid : EntityId)
      if mothman_server_launched_object__attachedClientEntity != newAttached
        return false
      destroyEntity(eid)
      return true

  print("[MOTHMAN] attaching client side obj <{mothman_server_launched_object__attachedClientEntity}> to server phys {phys_eid}")
  removeSubTemplate(mothman_server_launched_object__attachedClientEntity, "mothman_object_visual_effect")
  removeSubTemplate(mothman_server_launched_object__attachedClientEntity, "mothman_clientside_prepared_object")
  addSubTemplate(mothman_server_launched_object__attachedClientEntity, "mothman_clientside_launched_object") <| $(init)
    set(init, "mothman_clientside_launched_object__attachedServerEntity", phys_eid)
    set(init, "mothman_clientside_launched_object__launchedAt", get_sync_time())


[es(REQUIRE_NOT=hero, tag=gameClient)]
def mothman_attack_control_no_hero(evt : EventUpdateMothmanAttackState;
                                   var monstrified_mothman_attack__chosenObject : EntityId&;
                                   var monstrified_mothman_attack__chargedAt : float&;
                                   var monstrified_mothman_attack__isChanneling : bool&)
  monstrified_mothman_attack__isChanneling = evt.isChanneling
  monstrified_mothman_attack__chargedAt = evt.chargedAt
  monstrified_mothman_attack__chosenObject = evt.chosenObject


[es(tag=gameClient)]
def mothman_floating_object_update_impulse(upd : ParallelUpdateFrameDelayed;
                                           mothman_clientside_launched_object__attachedServerEntity : EntityId;
                                           var ri_extra__impulseOnDestruction : float3&;
                                           var ri_extra__impulsePosOnDestruction : float3&)
  query(mothman_clientside_launched_object__attachedServerEntity) <| $ [es] (phys_obj_net_phys : PhysObjActor; transform : float3x4)
    ri_extra__impulseOnDestruction = phys_obj_net_phys.phys.currentState.velocity * phys_obj_net_phys.phys.mass
    ri_extra__impulsePosOnDestruction = transform[3]


[es(tag=gameClient, on_disappear, REQUIRE=mothman_clientside_launched_object__attachedServerEntity)]
def cleanup_mothman_client_objects(evt : Event; eid aka disappearing_eid : EntityId)
  query() <| $ [es] (mothman_server_launched_object__attachedClientEntity : EntityId; eid aka other_eid : EntityId)
    if mothman_server_launched_object__attachedClientEntity == disappearing_eid
      destroyEntity(other_eid)


[es(tag=render, on_appear, after=init_mothman_floating_object_approach_from_pos_server)]
def mothman_floating_object_approach_from_pos_create_fx(evt : Event;
                                                        floating_object_approach_from_pos__pos : float3;
                                                        floating_object__owner : EntityId)
  query(floating_object__owner) <| $ [es] (monstrified_mothman_gathering__objectAppearFx : string)
    createEntity(monstrified_mothman_gathering__objectAppearFx) <| $(init)
      var tm = IDENT_TM
      tm[3] = floating_object_approach_from_pos__pos
      set(init, "transform", tm)

[es(before=floating_object_move, tag=gameClient)]
def mothman_floating_object_delayed_destruction_client(update : ParallelUpdateFrameDelayed;
                                                       mothman_floating_object_destruction__stoppingViscosity : float;
                                                       var euler_sinusoidal_oscillation__amplitude : float3&;
                                                       var floating_object__speed : float&)
  floating_object__speed = approach(floating_object__speed, 0.0, update.dt, mothman_floating_object_destruction__stoppingViscosity)
  euler_sinusoidal_oscillation__amplitude = approach(euler_sinusoidal_oscillation__amplitude, float3(0.0), update.dt, mothman_floating_object_destruction__stoppingViscosity)
