require ecs
require ecs.soa_template
require DagorSystem
require DagorMath
require DagorRandom
require math.base
require math.color
require math.random
require fx
require game.es.am_encounter_jump_quest_common
require game.es.render.camera_shaker_common
require game.events.events_active_matter

[es(tag=gameClient, after=encounter_jump_quest_core_projectile_update, after=interp_loc_snapshots_es)]
def encounter_jump_quest_core_projectile_update_client(evt : ParallelUpdateFrameDelayed;
                                                       encounter_jump_quest_core_projectile__state : int;
                                                       encounter_jump_quest_core_projectile__stateProgressTimer : float;
                                                       encounter_jump_quest_core_projectile__chargingToRamTime : float;
                                                       var transform aka projectile_transform : float3x4)
  assume state = encounter_jump_quest_core_projectile__state
  if state == int(EncounterJumpQuestCoreProjectileState.CHARGING_TO_RAM)
    let chargingProgress = encounter_jump_quest_core_projectile__stateProgressTimer / encounter_jump_quest_core_projectile__chargingToRamTime
    var shakeNoiseQuat : quat
    let angle = float2(0.0625, 0.125)
    euler_to_quat(chargingProgress * rnd_float(angle) * rnd_sign(),
                  chargingProgress * rnd_float(angle) * rnd_sign(),
                  chargingProgress * rnd_float(angle) * rnd_sign(),
                  shakeNoiseQuat)
    var shakeNoiseMat : float3x4
    make_tm(shakeNoiseQuat, shakeNoiseMat)
    projectile_transform = projectile_transform * shakeNoiseMat
  elif state == int(EncounterJumpQuestCoreProjectileState.RAM_ENEMY)
    var shakeNoiseQuat : quat
    let angle = float2(0.0525, 0.0725)
    euler_to_quat(rnd_float(angle) * rnd_sign(),
                  rnd_float(angle) * rnd_sign(),
                  rnd_float(angle) * rnd_sign(),
                  shakeNoiseQuat)
    var shakeNoiseMat : float3x4
    make_tm(shakeNoiseQuat, shakeNoiseMat)
    projectile_transform = projectile_transform * shakeNoiseMat
  elif state == int(EncounterJumpQuestCoreProjectileState.RAM_BOUNCE)
    var shakeNoiseQuat : quat
    let angle = float2(0.025, 0.035)
    euler_to_quat(rnd_float(angle) * rnd_sign(),
                  rnd_float(angle) * rnd_sign(),
                  rnd_float(angle) * rnd_sign(),
                  shakeNoiseQuat)
    var shakeNoiseMat : float3x4
    make_tm(shakeNoiseQuat, shakeNoiseMat)
    projectile_transform = projectile_transform * shakeNoiseMat


[es(tag=gameClient, track=encounter_jump_quest_core_projectile__state)]
def encounter_jump_quest_core_projectile_fx_controller_track_state(evt : Event;
                                                                   eid : EntityId;
                                                                   transform : float3x4;
                                                                   encounter_jump_quest_core_projectile__state : int;
                                                                   encounter_jump_quest_core_projectile_fx_controller__effectTemplate : string;
                                                                   var encounter_jump_quest_core_projectile_fx_controller__effectEid : EntityId&)
  assume effectEid = encounter_jump_quest_core_projectile_fx_controller__effectEid
  assume effectTemplate = encounter_jump_quest_core_projectile_fx_controller__effectTemplate
  if encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY)
    if effectEid == INVALID_ENTITY_ID
      effectEid = createEntity(effectTemplate) <| $(init)
        var tm = IDENT_TM
        tm[3] = transform[3]
        init |> set("transform", tm)
        init |> set("encounter_jump_quest_core_projectile_fx__owner", eid)
  elif (encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.MOVE_TO_IDLE_ORBIT) ||
       encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.IDLE))
    if effectEid != INVALID_ENTITY_ID
      destroyEntity(effectEid)
      effectEid = INVALID_ENTITY_ID


[es(tag=gameClient, no_order)]
def encounter_jump_quest_core_projectile_fx_update(act : ParallelUpdateFrameDelayed;
                                                   encounter_jump_quest_core_projectile_fx__owner : EntityId;
                                                   var encounter_jump_quest_core_projectile_fx__colorMult : E3DCOLOR&;
                                                   var encounter_jump_quest_core_projectile_fx__effectScale : float&;
                                                   var transform aka fx_transform : float3x4;
                                                   var effect__scale : float&;
                                                   var effect__colorMult : E3DCOLOR&)
  query(encounter_jump_quest_core_projectile_fx__owner) <| $ [es] (transform aka projectile_transform : float3x4;
                                                                   encounter_jump_quest_core_projectile__state : int;
                                                                   encounter_jump_quest_core_projectile__stateProgressTimer : float;
                                                                   encounter_jump_quest_core_projectile__chargingToRamTime : float;
                                                                   encounter_jump_quest_core_projectile_fx_controller__trackingScale : float;
                                                                   encounter_jump_quest_core_projectile_fx_controller__trackingColor : E3DCOLOR;
                                                                   encounter_jump_quest_core_projectile_fx_controller__ramScaleRng : float2;
                                                                   encounter_jump_quest_core_projectile_fx_controller__ramColorBegin : E3DCOLOR;
                                                                   encounter_jump_quest_core_projectile_fx_controller__ramColorEnd : E3DCOLOR)
    fx_transform[3] = projectile_transform[3]

    if encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.TRACKING_ENEMY)
      encounter_jump_quest_core_projectile_fx__effectScale = encounter_jump_quest_core_projectile_fx_controller__trackingScale
      encounter_jump_quest_core_projectile_fx__colorMult = encounter_jump_quest_core_projectile_fx_controller__trackingColor
    elif encounter_jump_quest_core_projectile__state == int(EncounterJumpQuestCoreProjectileState.CHARGING_TO_RAM)
      let ramProgress = encounter_jump_quest_core_projectile__stateProgressTimer / encounter_jump_quest_core_projectile__chargingToRamTime
      encounter_jump_quest_core_projectile_fx__effectScale = lerp(encounter_jump_quest_core_projectile_fx_controller__ramScaleRng.x,
                                                                  encounter_jump_quest_core_projectile_fx_controller__ramScaleRng.y,
                                                                  ramProgress)
      encounter_jump_quest_core_projectile_fx__colorMult = lerp_color(encounter_jump_quest_core_projectile_fx_controller__ramColorBegin,
                                                                      encounter_jump_quest_core_projectile_fx_controller__ramColorEnd,
                                                                      ramProgress)

    effect__scale = lerp(effect__scale, encounter_jump_quest_core_projectile_fx__effectScale, 4.0 * act.dt)
    effect__colorMult = lerp_color(effect__colorMult, encounter_jump_quest_core_projectile_fx__colorMult, 8.0 * act.dt)


[es(tag=gameClient, on_disappear)]
def encounter_jump_quest_core_projectile_fx_controller_disappear_client(evt : Event;
                                                                        encounter_jump_quest_core_projectile_fx_controller__effectEid : EntityId)
  destroyEntity(encounter_jump_quest_core_projectile_fx_controller__effectEid)


[es(tag=gameClient, REQUIRE=encounter_jump_quest_core, track=isAlive)]
def encounter_jump_quest_am_core_track_alive_client(evt : Event;
                                                    transform : float3x4;
                                                    isAlive : bool;
                                                    encounter_jump_quest_core__explosionFx : string)
  if !isAlive
    var tm = IDENT_TM
    tm[3] = transform[3]
    start_effect(get_type_by_name(encounter_jump_quest_core__explosionFx),
                tm,
                IDENT_TM,
                true)


[es(tag=gameClient, on_appear)]
def encounter_jump_quest_earthshake_init_client(evt : Event;
                                                transform aka earthshake_transform : float3x4;
                                                sphere_zone__radius : float;
                                                encounter_jump_quest_earthshake__initialPunch : float)
  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let distance = distance(earthshake_transform[3], camera_transform[3])
    let distanceKoef = 1.0 - square(saturate(safediv(distance, sphere_zone__radius)))
    let punch = float3(rnd_sign(), rnd_sign(), 0.0) * distanceKoef * encounter_jump_quest_earthshake__initialPunch
    add_punch(punch)
    return true


[es(tag=gameClient, no_order)]
def encounter_jump_quest_earthshake_update_client(act : ParallelUpdateFrameDelayed;
                                                  transform aka earthshake_transform : float3x4;
                                                  sphere_zone__radius : float;
                                                  encounter_jump_quest_earthshake__cameraTrauma : float;
                                                  encounter_jump_quest_earthshake__startAt : float;
                                                  encounter_jump_quest_earthshake__time : float)
  if encounter_jump_quest_earthshake__cameraTrauma <= 0.0
    return
  let endAt = encounter_jump_quest_earthshake__startAt + encounter_jump_quest_earthshake__time
  let progress = cvt(act.curTime, encounter_jump_quest_earthshake__startAt, endAt, 0.0, 1.0)
  find_query() <| $ [es] (camera__active : bool;
                          transform aka camera_transform : float3x4)
    if !camera__active
      return false

    let distance = distance(earthshake_transform[3], camera_transform[3])
    let distanceKoef = 1.0 - square(saturate(safediv(distance, sphere_zone__radius)))
    let trauma = encounter_jump_quest_earthshake__cameraTrauma * (1.0 - progress) * distanceKoef
    add_trauma(trauma, trauma)
    return true


[soa_es, es(tag=gameClient, track=encounter_jump_quest_node_rendinst__state)]
def encounter_jump_quest_node_rendinst_state_track_client(evt : Event;
                                                          encounter_jump_quest_node_rendinst__state : int;
                                                          encounter_jump_quest_node_rendinst__jumpQuestEid : EntityId;
                                                          encounter_jump_quest_node_rendinst__nodeIndex : int;
                                                          encounter_jump_quest_node_rendinst__punchNodeIndex : int;
                                                          encounter_jump_quest_node_rendinst__demolitionEffectTemplate : string)

  if encounter_jump_quest_node_rendinst__state == int(EncounterJumpQuestNodeRendinstState.DEMOLITION)
    query(encounter_jump_quest_node_rendinst__jumpQuestEid) <| $ [soa_blk, es] (encounter_jump_quest__nodes : EncounterJumpQuestNode_SOA)
      assume nodeIndex = encounter_jump_quest_node_rendinst__nodeIndex
      assume nodeType = encounter_jump_quest__nodes[nodeIndex].encounter_jump_quest__nodes__type
      assume punchNodeIndex = encounter_jump_quest_node_rendinst__punchNodeIndex
      if (((nodeType == int(EncounterJumpQuestNodeType.PATH)) && (nodeIndex % punchNodeIndex != 0)) ||
        nodeType == int(EncounterJumpQuestNodeType.TOP_PLATFORM))
        let nodeCollisionTm = encounter_jump_quest__nodes[nodeIndex].encounter_jump_quest__nodes__collisionTm
        let tm = nodeCollisionTm
        let fxType = get_type_by_name(encounter_jump_quest_node_rendinst__demolitionEffectTemplate)

        start_effect(fxType,
                      tm,
                      IDENT_TM,
                      false)